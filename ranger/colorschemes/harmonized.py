from __future__ import (absolute_import, division, print_function)

from ranger.colorschemes.default import Default
from ranger.gui.color import yellow


class Scheme(Default):
    def use(self, context):
        fg, bg, attr = Default.use(self, context)

        if context.in_browser and context.directory:
            fg = yellow

        if context.in_titlebar and context.directory:
            fg = yellow

        return fg, bg, attr
