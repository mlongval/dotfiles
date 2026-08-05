from __future__ import (absolute_import, division, print_function)

from ranger.colorschemes.default import Default
from ranger.gui.color import yellow, default, bold


class Scheme(Default):
    def use(self, context):
        fg, bg, attr = Default.use(self, context)

        if context.in_browser and context.directory:
            fg = yellow

        if context.in_titlebar and context.directory:
            fg = yellow

        # Render executable files exactly like regular files. Default colours
        # them bright green, which in Catppuccin Mocha (#a6e3a1) is a
        # desaturated sage that reads as muddy grey on the dark background.
        if context.in_browser and context.executable and not any((
                context.directory, context.link, context.socket,
                context.fifo, context.device, context.media,
                context.container)):
            # Strip the green tint, but leave the state colours Default applies
            # to ALL files (marked -> yellow, cut/copied -> dim) intact so an
            # executable looks exactly like a regular file in every state.
            if not (context.marked or context.cut or context.copied):
                fg = default
            # Default adds bold solely to flag executability; drop it unless
            # bold is warranted for another reason (cursor/marked/cut).
            if not (context.selected or context.marked
                    or context.cut or context.copied):
                attr &= ~bold

        return fg, bg, attr
