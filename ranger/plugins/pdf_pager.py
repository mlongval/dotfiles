# Page through multi-page PDFs in the preview pane with '>' / '<'.
#
# ranger's own PDF preview (see scope.sh's handle_image) only ever
# renders page 1, and it's cached per-file in ranger's `fm.previews`
# dict keyed by realpath - there's no built-in notion of "page". So
# this bypasses that pipeline entirely: it renders the requested page
# straight to a temp file with pdftoppm and draws it directly over the
# preview column with the active image displayer (chafa/kitty), same
# geometry ranger itself would use.
#
# Like chafa_ghostty.py, this only does anything inside Ghostty: outside
# it, image previews stay off (rc.conf default) and the active displayer
# isn't the chafa/kitty one this relies on, so it'd be drawing garbage.
#
# Page state is remembered per file for the session but isn't wired
# into ranger's own redraw cycle: moving the cursor off the file and
# back re-triggers ranger's normal page-1 preview without resetting
# our counter, so the first '>' press after that jumps from the old
# page rather than page 1. Minor rough edge, not worth chasing.

import os
import re
import subprocess
import tempfile

from ranger.api.commands import Command

IS_GHOSTTY = bool(os.environ.get("GHOSTTY_RESOURCES_DIR"))

_PAGE = {}        # realpath -> current page number
_PAGE_COUNT = {}  # realpath -> total page count


def _page_count(path):
    if path not in _PAGE_COUNT:
        try:
            out = subprocess.check_output(
                ["pdfinfo", "--", path], stderr=subprocess.DEVNULL
            ).decode("utf-8", "replace")
            match = re.search(r"^Pages:\s+(\d+)", out, re.MULTILINE)
            _PAGE_COUNT[path] = int(match.group(1)) if match else 1
        except (subprocess.CalledProcessError, OSError):
            _PAGE_COUNT[path] = 1
    return _PAGE_COUNT[path]


def _render_page(fm, path, page):
    column = fm.ui.browser.columns[-1]
    outbase = os.path.join(
        tempfile.gettempdir(), "ranger_pdfpage_{0}".format(os.getpid())
    )
    try:
        subprocess.run(
            [
                "pdftoppm", "-f", str(page), "-l", str(page),
                "-scale-to-x", "1920", "-scale-to-y", "-1",
                "-singlefile", "-jpeg", "-tiffcompression", "jpeg",
                "--", path, outbase,
            ],
            check=True, stderr=subprocess.DEVNULL,
        )
    except (subprocess.CalledProcessError, OSError):
        fm.notify(
            "Could not render page {0} of {1}".format(page, os.path.basename(path)),
            bad=True,
        )
        return
    outfile = outbase + ".jpg"
    if not os.path.isfile(outfile):
        return
    fm.image_displayer.draw(outfile, column.x, column.y, column.wid, column.hei)
    os.remove(outfile)


def _turn_page(fm, delta):
    if not IS_GHOSTTY:
        fm.notify("PDF paging only works in Ghostty", bad=True)
        return
    target = fm.thisfile
    if target is None or not target.path.lower().endswith(".pdf"):
        fm.notify("Not previewing a PDF", bad=True)
        return
    path = target.realpath
    total = _page_count(path)
    current = _PAGE.get(path, 1)
    new_page = min(max(current + delta, 1), total)
    if new_page == current:
        fm.notify("Page {0}/{1}".format(current, total))
        return
    _PAGE[path] = new_page
    _render_page(fm, path, new_page)
    fm.notify("Page {0}/{1}".format(new_page, total))


class pdf_next_page(Command):
    def execute(self):
        _turn_page(self.fm, 1)


class pdf_prev_page(Command):
    def execute(self):
        _turn_page(self.fm, -1)
