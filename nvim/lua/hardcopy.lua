-- ~/.config/nvim/lua/hardcopy.lua
--
-- Neovim hardcopy (stable, UTF-8 safe, exact margins) + niceties:
--   ✅ Headers/footers (date + filename + page X/Y)
--   ✅ Page numbers
--   ✅ Optional line numbers in left margin
--   ✅ Auto paper (A4 vs LETTER) by locale, with override
--   ✅ Second command :HCnarrow with alternate layout
--
-- Dependencies (once):
--   sudo apt update
--   sudo apt install python3-reportlab fontconfig fonts-dejavu-core


local PYTHON = "/usr/bin/python3"
-- ============================================================
-- USER CONFIGURATION (EDIT HERE)
-- ============================================================

-- Primary (HC) layout
local HC = {
  margins_mm = { left = 22, right = 12, top = 14, bottom = 24 }, -- top includes header area
  font_family = "DejaVu Sans Mono",
  font_size_pt = 14,
  line_spacing = 1.25,
  show_line_numbers = false,     -- toggle line numbers
  header = true,
  footer = true,
}

-- Narrow (HCnarrow) layout (handy for longer notes)
local HCN = {
  margins_mm = { left = 16, right = 10, top = 12, bottom = 18 },
  font_family = "DejaVu Sans Mono",
  font_size_pt = 12,
  line_spacing = 1.20,
  show_line_numbers = false,
  header = true,
  footer = true,
}

-- Paper size:
--   "AUTO" (choose A4 if locale looks non-US, else LETTER)
--   or force "A4" / "LETTER"
local PAPER_MODE = "AUTO"

-- Optional: force printer queue (nil = default)
local PRINTER = nil -- e.g. "hdieu_remote"

-- Debug: keep temp files and show commands
local DEBUG = false

-- Header/footer styling
local HEADER_FONT_SCALE = 0.85   -- header/footer font relative to body
local HEADER_RULE = true         -- draw a thin rule under header
local FOOTER_RULE = false        -- draw a thin rule above footer

-- ============================================================
-- END USER CONFIGURATION
-- ============================================================

local M = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO)
end

local function get_buf_lines(buf, l1, l2)
  if l1 < 1 then l1 = 1 end
  if l2 < l1 then l2 = l1 end
  return vim.api.nvim_buf_get_lines(buf, l1 - 1, l2, false)
end

local function write_tmp(lines, ext)
  local tmp = vim.fn.tempname() .. (ext or "")
  vim.fn.writefile(lines, tmp)
  return tmp
end

local function sys(cmd)
  if DEBUG then
    notify("HC debug command:\n" .. cmd)
  end
  local out = vim.fn.system(cmd)
  return out, vim.v.shell_error
end

local function current_buf_label()
  local name = vim.api.nvim_buf_get_name(0)
  if name == nil or name == "" then
    return "[No Name]"
  end
  -- shorten to tail for printing
  return vim.fn.fnamemodify(name, ":t")
end

local function pick_paper()
  if PAPER_MODE == "A4" or PAPER_MODE == "LETTER" then
    return PAPER_MODE
  end
  -- AUTO
  local lang = (os.getenv("LC_ALL") or os.getenv("LC_PAPER") or os.getenv("LANG") or ""):lower()
  -- crude heuristic: if looks like US locale -> LETTER else A4
  if lang:find("en_us", 1, true) or lang:find("c%.utf%-8", 1, false) then
    return "LETTER"
  end
  return "A4"
end

local function python_escape_q(s)
  -- Lua %q gives a quoted Lua string; Python accepts the same quoting style for our use here
  return string.format("%q", s)
end

local function build_python(layout, txt, pdf, meta)
  local paper = pick_paper()

  local margins = layout.margins_mm
  local font_family = layout.font_family
  local font_size = layout.font_size_pt
  local line_spacing = layout.line_spacing

  local show_ln = layout.show_line_numbers and "True" or "False"
  local header_on = layout.header and "True" or "False"
  local footer_on = layout.footer and "True" or "False"

  local header_rule = HEADER_RULE and "True" or "False"
  local footer_rule = FOOTER_RULE and "True" or "False"

  local py = string.format([[
import os, subprocess, datetime, locale

from reportlab.lib.pagesizes import %s
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

mm = 72.0 / 25.4

# Layout
LEFT   = %.2f * mm
RIGHT  = %.2f * mm
TOP    = %.2f * mm
BOTTOM = %.2f * mm

FONT_FAMILY = %s
FONT_SIZE = %d
LINE_SPACING = %.3f

SHOW_LINE_NUMBERS = %s
HEADER_ON = %s
FOOTER_ON = %s

HEADER_FONT_SCALE = %.3f
HEADER_RULE = %s
FOOTER_RULE = %s

TXT_PATH = %s
PDF_PATH = %s

TITLE = %s
RANGE_LABEL = %s
NOW_STR = %s

width, height = %s

def find_font_file(family: str) -> str:
    try:
        p = subprocess.run(
            ["fc-match", "-f", "%%{file}", family],
            check=True, capture_output=True, text=True
        )
        path = (p.stdout or "").strip()
        if path and os.path.exists(path):
            return path
    except Exception:
        pass

    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf",
        "/usr/share/fonts/truetype/liberation2/LiberationMono-Regular.ttf",
        "/usr/share/fonts/truetype/noto/NotoSansMono-Regular.ttf",
        "/usr/share/fonts/opentype/noto/NotoSansMono-Regular.otf",
    ]
    for c in candidates:
        if os.path.exists(c):
            return c

    raise RuntimeError(
        f"Could not locate a TTF/OTF font file for family: {family}. "
        f"Install fonts (e.g. fonts-dejavu-core) and/or fontconfig (fc-match)."
    )

font_file = find_font_file(FONT_FAMILY)
pdf_font_name = "HCFont"
pdfmetrics.registerFont(TTFont(pdf_font_name, font_file))

c = canvas.Canvas(PDF_PATH, pagesize=(width, height))

# Measure spaces for simple monospaced layout assumptions (still okay for our use)
def set_body_font():
    c.setFont(pdf_font_name, FONT_SIZE)

def set_hf_font():
    c.setFont(pdf_font_name, max(6, int(FONT_SIZE * HEADER_FONT_SCALE)))

def draw_rule(y):
    c.setLineWidth(0.5)
    c.line(LEFT, y, width - RIGHT, y)

# Determine line number gutter (if enabled)
# We reserve space for up to 5 digits by default; adjust if you like.
LN_GUTTER = 0
if SHOW_LINE_NUMBERS:
    # approx width: 6 chars + a space
    set_body_font()
    LN_GUTTER = c.stringWidth("000000 ", pdf_font_name, FONT_SIZE)

# Header/footer reserved height
set_hf_font()
HF_H = c._fontsize * 1.4  # a bit of breathing room

# Compute writing area
write_top = height - TOP
write_bottom = BOTTOM
if HEADER_ON:
    write_top -= HF_H
if FOOTER_ON:
    write_bottom += HF_H

set_body_font()
line_h = FONT_SIZE * LINE_SPACING

# First pass: read and sanitize lines, also store original line numbers
lines = []
with open(TXT_PATH, "r", encoding="utf-8", errors="replace") as f:
    for idx, line in enumerate(f, start=1):
        s = line.rstrip("\r\n")
        s = "".join(ch for ch in s if (ch >= " " or ch == "\t"))
        s = s.replace("\t", "    ")
        lines.append((idx, s))

# Pagination
lines_per_page = int((write_top - write_bottom) // line_h) if (write_top > write_bottom) else 1
if lines_per_page < 1:
    lines_per_page = 1

total_pages = (len(lines) + lines_per_page - 1) // lines_per_page

def draw_header(page_no: int):
    if not HEADER_ON:
        return
    set_hf_font()
    y = height - TOP + (HF_H * 0.25)
    left_txt = f"{TITLE}"
    right_txt = f"{NOW_STR}"
    mid_txt = f"{RANGE_LABEL}" if RANGE_LABEL else ""
    c.drawString(LEFT, y, left_txt)
    if mid_txt:
        c.drawCentredString(width / 2.0, y, mid_txt)
    c.drawRightString(width - RIGHT, y, right_txt)
    if HEADER_RULE:
        draw_rule(height - TOP - (HF_H * 0.15))

def draw_footer(page_no: int, total_pages: int):
    if not FOOTER_ON:
        return
    set_hf_font()
    y = BOTTOM - (HF_H * 0.85)
    if FOOTER_RULE:
        draw_rule(BOTTOM + (HF_H * 0.15))
    c.drawString(LEFT, y, " ")
    c.drawRightString(width - RIGHT, y, f"Page {page_no}/{total_pages}")

# Render pages
for p in range(total_pages):
    page_no = p + 1
    draw_header(page_no)
    draw_footer(page_no, total_pages)

    set_body_font()
    y = write_top - line_h  # start a line down from the top of write area

    start = p * lines_per_page
    end = min(len(lines), start + lines_per_page)
    for (idx, s) in lines[start:end]:
        x = LEFT
        if SHOW_LINE_NUMBERS:
            # right-align line numbers in gutter
            ln = f"{idx:>6} "
            c.drawString(x, y, ln)
            x += LN_GUTTER
        c.drawString(x, y, s)
        y -= line_h

    if page_no != total_pages:
        c.showPage()

c.save()
]],
    paper,
    margins.left, margins.right, margins.top, margins.bottom,
    python_escape_q(font_family),
    font_size,
    line_spacing,
    show_ln,
    header_on,
    footer_on,
    HEADER_FONT_SCALE,
    header_rule,
    footer_rule,
    python_escape_q(txt),
    python_escape_q(pdf),
    python_escape_q(meta.title),
    python_escape_q(meta.range_label or ""),
    python_escape_q(meta.now_str),
    paper
  )

  return py
end

local function render_and_print(layout, line1, line2)
  local total = vim.api.nvim_buf_line_count(0)
  local l1 = line1 or 1
  local l2 = line2 or total

  local lines = get_buf_lines(0, l1, l2)
  local txt = write_tmp(lines, ".txt")
  local pdf = vim.fn.tempname() .. ".pdf"

  local meta = {
    title = current_buf_label(),
    range_label = (l1 == 1 and l2 == total) and "" or ("Lines " .. l1 .. "–" .. l2),
    now_str = os.date("%Y-%m-%d %H:%M"),
  }

  local python = build_python(layout, txt, pdf, meta)

  local out1, err1 = sys(PYTHON .. " - <<'EOF'\n" .. python .. "\nEOF")
  if err1 ~= 0 then
    notify("HC failed while generating PDF:\n" .. (out1 or ""), vim.log.levels.ERROR)
    if DEBUG then
      notify("HC debug: temp files kept:\n" .. txt .. "\n" .. pdf)
    end
    return
  end

  local lpr_cmd = "lpr " .. (PRINTER and ("-P " .. PRINTER .. " ") or "") .. pdf
  local out2, err2 = sys(lpr_cmd)

  if not DEBUG then
    pcall(vim.fn.delete, txt)
    pcall(vim.fn.delete, pdf)
  else
    notify("HC debug: temp files kept:\n" .. txt .. "\n" .. pdf)
  end

  if err2 ~= 0 then
    notify("HC failed while printing:\n" .. (out2 or ""), vim.log.levels.ERROR)
  else
    notify("Printed successfully")
  end
end

function M.setup()
  vim.api.nvim_create_user_command("HC", function(opts)
    local total = vim.api.nvim_buf_line_count(0)
    local l1, l2
    if opts.range == 0 then
      l1, l2 = 1, total
    else
      l1, l2 = opts.line1, opts.line2
    end
    render_and_print(HC, l1, l2)
  end, {
    range = true,
    desc = "Hardcopy: primary layout (UTF-8 PDF + headers/footers/pages)",
  })

  vim.api.nvim_create_user_command("HCnarrow", function(opts)
    local total = vim.api.nvim_buf_line_count(0)
    local l1, l2
    if opts.range == 0 then
      l1, l2 = 1, total
    else
      l1, l2 = opts.line1, opts.line2
    end
    render_and_print(HCN, l1, l2)
  end, {
    range = true,
    desc = "Hardcopy: narrow layout (smaller font/margins)",
  })
end

return M

