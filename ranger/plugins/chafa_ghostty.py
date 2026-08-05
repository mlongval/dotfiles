# Enables ranger's image previews via chafa, but only when running inside
# Ghostty (detected via the GHOSTTY_RESOURCES_DIR env var it sets). On any
# other terminal, ranger falls back to whatever rc.conf already configures.
#
# Renders via chafa's Kitty-graphics-protocol output (--format=kitty) rather
# than its Unicode symbol/block-art mode: Ghostty renders chafa's block and
# braille glyphs as double-width (they're Unicode "ambiguous width"
# characters), which corrupted symbol-mode previews into duplicated,
# line-wrapped garbage. Kitty protocol sends real pixels, sidestepping that
# entirely, and Ghostty supports it natively.

import os
import sys
from subprocess import PIPE, Popen

import ranger.api
from ranger.core.shared import FileManagerAware
from ranger.ext.img_display import ImageDisplayer, move_cur, register_image_displayer

IS_GHOSTTY = bool(os.environ.get("GHOSTTY_RESOURCES_DIR"))
_STDOUT = getattr(sys.stdout, "buffer", sys.stdout)


@register_image_displayer("chafa")
class ChafaImageDisplayer(ImageDisplayer, FileManagerAware):
    """Renders images via chafa, emitting the Kitty graphics protocol."""

    def draw(self, path, start_x, start_y, width, height):
        self.clear(start_x, start_y, width, height)
        move_cur(start_y, start_x)
        try:
            process = Popen(
                ["chafa", "--size={0}x{1}".format(width, height), "--format=kitty", path],
                stdout=PIPE, stderr=PIPE,
            )
            output, _ = process.communicate()
        except OSError:
            return
        _STDOUT.write(output)
        _STDOUT.flush()

    def clear(self, start_x, start_y, width, height):
        # Kitty-protocol images live on a layer above the text grid, so a
        # curses redraw alone won't remove them - explicitly delete all
        # placements first.
        _STDOUT.write(b"\x1b_Ga=d\x1b\\")
        _STDOUT.flush()
        self.fm.ui.win.redrawwin()
        self.fm.ui.win.refresh()


_prev_hook_init = ranger.api.hook_init


def _hook_init(fm):
    if IS_GHOSTTY:
        fm.execute_console("set preview_images true")
        fm.execute_console("set preview_images_method chafa")
    return _prev_hook_init(fm)


ranger.api.hook_init = _hook_init
