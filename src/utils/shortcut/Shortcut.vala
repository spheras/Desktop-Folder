/*
 * Copyright (c) 2017-2019 José Amuedo (https://github.com/spheras)
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace Pantheon.Keyboard.Shortcuts {
    // stores a shortcut, converts to gsettings format and readable format
    // and checks for validity
    class Shortcut : GLib.Object {
        public Gdk.ModifierType modifiers;
        public uint accel_key;

        /* NEVER USED
           string SEPARATOR = " · ";
         */

        // constructors
        public Shortcut (uint key = 0, Gdk.ModifierType mod = (Gdk.ModifierType) 0) {
            accel_key = key;
            modifiers = mod;
        }

        public Shortcut.parse (string ? str)
        {
            if (str == null) {
                accel_key = 0;
                modifiers = (Gdk.ModifierType) 0;
                return;
            }
            Gtk.accelerator_parse (str, out accel_key, out modifiers);
        }

        // converters
        public string to_gsettings () {
            if (!valid ())
                return "";
            return Gtk.accelerator_name (accel_key, modifiers);
        }

        /* NEVER USED
           public string to_readable  ()
           {
                if (!valid())
                        return _("Disabled");

                string tmp = "";

                if ((modifiers & Gdk.ModifierType.SHIFT_MASK) > 0)
                    tmp += "⇧" + SEPARATOR;
                if ((modifiers & Gdk.ModifierType.SUPER_MASK) > 0)
                    tmp += "⌘" + SEPARATOR;
                if ((modifiers & Gdk.ModifierType.CONTROL_MASK) > 0)
                    tmp += _("Ctrl") + SEPARATOR;
                if ((modifiers & Gdk.ModifierType.MOD1_MASK) > 0)
                    tmp += "⎇" + SEPARATOR;
                if ((modifiers & Gdk.ModifierType.MOD2_MASK) > 0)
                    tmp += "Mod2" + SEPARATOR;
                if ((modifiers & Gdk.ModifierType.MOD3_MASK) > 0)
                    tmp += "Mod3" + SEPARATOR;
                if ((modifiers & Gdk.ModifierType.MOD4_MASK) > 0)
                    tmp += "Mod4" + SEPARATOR;

           switch (accel_key) {

           case Gdk.Key.Tab:   tmp += "↹"; break;
           case Gdk.Key.Up:    tmp += "↑"; break;
           case Gdk.Key.Down:  tmp += "↓"; break;
           case Gdk.Key.Left:  tmp += "←"; break;
           case Gdk.Key.Right: tmp += "→"; break;
           default:
            tmp += Gtk.accelerator_get_label (accel_key, 0);
            break;
           }

                return tmp;
           }
         */

        public bool is_equal (Shortcut shortcut) {
            // debug("is equal? %d, %d : %d, %d",shortcut.modifiers, modifiers, (int)shortcut.accel_key, (int) accel_key);
            if (shortcut.modifiers == modifiers) {
                if (shortcut.accel_key == accel_key) {
                    return true;
                }
            }
            return false;
        }

        // validator
        public bool valid () {
            if (accel_key == 0 || (modifiers == (Gdk.ModifierType) 0 && accel_key != Gdk.Key.Print))
                return false;

            if (modifiers == Gdk.ModifierType.SHIFT_MASK) {
                if ((accel_key >= Gdk.Key.a && accel_key <= Gdk.Key.z)
                    || (accel_key >= Gdk.Key.A && accel_key <= Gdk.Key.Z)
                    || (accel_key >= Gdk.Key.@0 && accel_key <= Gdk.Key.@9)
                    || (accel_key >= Gdk.Key.kana_fullstop && accel_key <= Gdk.Key.semivoicedsound)
                    || (accel_key >= Gdk.Key.Arabic_comma && accel_key <= Gdk.Key.Arabic_sukun)
                    || (accel_key >= Gdk.Key.Serbian_dje && accel_key <= Gdk.Key.Cyrillic_HARDSIGN)
                    || (accel_key >= Gdk.Key.Greek_ALPHAaccent && accel_key <= Gdk.Key.Greek_omega)
                    || (accel_key >= Gdk.Key.hebrew_doublelowline && accel_key <= Gdk.Key.hebrew_taf)
                    || (accel_key >= Gdk.Key.Thai_kokai && accel_key <= Gdk.Key.Thai_lekkao)
                    || (accel_key >= Gdk.Key.Hangul && accel_key <= Gdk.Key.Hangul_Special)
                    || (accel_key >= Gdk.Key.Hangul_Kiyeog && accel_key <= Gdk.Key.Hangul_J_YeorinHieuh)
                    || (accel_key == Gdk.Key.Home)
                    || (accel_key == Gdk.Key.Left)
                    || (accel_key == Gdk.Key.Up)
                    || (accel_key == Gdk.Key.Right)
                    || (accel_key == Gdk.Key.Down)
                    || (accel_key == Gdk.Key.Page_Up)
                    || (accel_key == Gdk.Key.Page_Down)
                    || (accel_key == Gdk.Key.End)
                    || (accel_key == Gdk.Key.Tab)
                    || (accel_key == Gdk.Key.KP_Enter)
                    || (accel_key == Gdk.Key.Return)) {
                    return false;
                }
            }

            return true;
        }

    }
}
