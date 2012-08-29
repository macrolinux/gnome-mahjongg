public class Mahjongg : Gtk.Application
{
    private Settings settings;

    private GnomeGamesSupport.Scores highscores;

    private List<Map> maps = null;

    private Gtk.ApplicationWindow window;
    private int window_width;
    private int window_height;
    private bool is_fullscreen;
    private bool is_maximized;

    private GameView game_view;
    private Gtk.ToolButton pause_button;
    private Gtk.ToolItem status_item;
    private Gtk.Label moves_label;
    private Gtk.Label clock_label;
    private Gtk.Dialog? preferences_dialog = null;

    public Mahjongg ()
    {
        Object (application_id: "org.gnome.gnome-mahjongg", flags: ApplicationFlags.FLAGS_NONE);

        add_action_entries (action_entries, this);
        add_accelerator ("<Primary>n", "app.new-game", null);
        add_accelerator ("Pause", "app.pause", null);
        add_accelerator ("<Primary>h", "app.hint", null);
        add_accelerator ("<Primary>z", "app.undo", null);
        add_accelerator ("<Primary><Shift>z", "app.redo", null);
        add_accelerator ("<Primary>q", "app.quit", null);
    }

    protected override void startup ()
    {
        base.startup ();

        settings = new Settings ("org.gnome.gnome-mahjongg");

        load_maps ();

        highscores = new GnomeGamesSupport.Scores ("gnome-mahjongg",
                                                   new GnomeGamesSupport.ScoresCategory[0],
                                                   null, null, 0,
                                                   GnomeGamesSupport.ScoreStyle.TIME_ASCENDING);
        foreach (var map in maps)
        {
            var display_name = dpgettext2 (null, "mahjongg map name", map.name);
            highscores.add_category (map.score_name, display_name);
        }

        window = new Gtk.ApplicationWindow (this);
        window.title = _("Mahjongg");
        window.configure_event.connect (window_configure_event_cb);
        window.window_state_event.connect (window_state_event_cb);
        window.set_default_size (settings.get_int ("window-width"), settings.get_int ("window-height"));        
        if (settings.get_boolean ("window-is-fullscreen"))
            window.fullscreen ();
        else if (settings.get_boolean ("window-is-maximized"))
            window.maximize ();

        var status_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);

        var group_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        var label = new Gtk.Label (_("Moves Left:"));
        group_box.pack_start (label, false, false, 0);
        var spacer = new Gtk.Label (" ");
        group_box.pack_start (spacer, false, false, 0);
        moves_label = new Gtk.Label ("");
        group_box.pack_start (moves_label, false, false, 0);
        status_box.pack_start (group_box, false, false, 0);

        clock_label = new Gtk.Label ("");
        status_box.pack_start (clock_label, false, false, 0);
        
        var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

        /* Create the menus */
        var menu = new Menu ();
        var section = new Menu ();
        menu.append_section (null, section);
        section.append (_("_New Game"), "app.new-game");
        section.append (_("_Restart Game"), "app.restart-game");
        section.append (_("_Scores"), "app.scores");
        section.append (_("_Preferences"), "app.preferences");
        section = new Menu ();
        menu.append_section (null, section);
        section.append (_("_Help"), "app.help");
        section.append (_("_About"), "app.about");
        section = new Menu ();
        menu.append_section (null, section);
        section.append (_("_Quit"), "app.quit");
        set_app_menu (menu);

        game_view = new GameView ();
        game_view.button_press_event.connect (view_button_press_event);        
        game_view.set_size_request (600, 400);

        var toolbar = new Gtk.Toolbar ();
        toolbar.show_arrow = false;
        toolbar.get_style_context ().add_class (Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);

        var new_game_button = new Gtk.ToolButton (null, _("_New"));
        new_game_button.use_underline = true;
        new_game_button.icon_name = "document-new";
        new_game_button.action_name = "app.new-game";
        new_game_button.show ();
        toolbar.insert (new_game_button, -1);

        var undo_button = new Gtk.ToolButton (null, _("_Undo Move"));
        undo_button.use_underline = true;
        undo_button.icon_name = "edit-undo";
        undo_button.action_name = "app.undo";
        undo_button.is_important = true;
        undo_button.show ();
        toolbar.insert (undo_button, -1);

        var redo_button = new Gtk.ToolButton (null, _("_Redo Move"));
        redo_button.use_underline = true;
        redo_button.icon_name = "edit-redo";
        redo_button.action_name = "app.redo";
        redo_button.is_important = true;
        redo_button.show ();
        toolbar.insert (redo_button, -1);

        var hint_button = new Gtk.ToolButton (null, _("Hint"));
        hint_button.use_underline = true;
        hint_button.icon_name = "dialog-information";
        hint_button.action_name = "app.hint";
        hint_button.is_important = true;
        hint_button.show ();
        toolbar.insert (hint_button, -1);

        pause_button = new Gtk.ToolButton (null, _("_Pause"));
        pause_button.icon_name = "media-playback-pause";
        pause_button.use_underline = true;
        pause_button.action_name = "app.pause";
        pause_button.is_important = true;
        pause_button.show ();
        toolbar.insert (pause_button, -1);

        var status_alignment = new Gtk.Alignment (1.0f, 0.5f, 0.0f, 0.0f);
        status_alignment.add (status_box);

        status_item = new Gtk.ToolItem ();
        status_item.set_expand (true);
        status_item.add (status_alignment);

        toolbar.insert (status_item, -1);

        vbox.pack_start (toolbar, false, false, 0);
        vbox.pack_start (game_view, true, true, 0);

        window.add (vbox);
        vbox.show_all ();

        settings.changed.connect (conf_value_changed_cb);

        new_game ();

        game_view.grab_focus ();

        conf_value_changed_cb (settings, "tileset");
        conf_value_changed_cb (settings, "bgcolour");
        tick_cb ();
    }

    private bool window_configure_event_cb (Gdk.EventConfigure event)
    {
        if (!is_maximized && !is_fullscreen)
        {
            window_width = event.width;
            window_height = event.height;
        }

        return false;
    }

    private bool window_state_event_cb (Gdk.EventWindowState event)
    {
        if ((event.changed_mask & Gdk.WindowState.MAXIMIZED) != 0)
            is_maximized = (event.new_window_state & Gdk.WindowState.MAXIMIZED) != 0;
        if ((event.changed_mask & Gdk.WindowState.FULLSCREEN) != 0)
            is_fullscreen = (event.new_window_state & Gdk.WindowState.FULLSCREEN) != 0;
        return false;
    }
    
    protected override void shutdown ()
    {
        base.shutdown ();

        /* Save window state */
        settings.set_int ("window-width", window_width);
        settings.set_int ("window-height", window_height);
        settings.set_boolean ("window-is-maximized", is_maximized);
        settings.set_boolean ("window-is-fullscreen", is_fullscreen);
    }

    public override void activate ()
    {
        window.present ();
    }

    private void update_ui ()
    {
        var pause_action = lookup_action ("pause") as SimpleAction;
        var hint_action = lookup_action ("hint") as SimpleAction;
        var undo_action = lookup_action ("undo") as SimpleAction;
        var redo_action = lookup_action ("redo") as SimpleAction;

        pause_action.set_enabled (game_view.game.started);

        if (game_view.game.paused)
        {
            hint_action.set_enabled (false);
            undo_action.set_enabled (false);
            redo_action.set_enabled (false);
        }
        else
        {
            hint_action.set_enabled (game_view.game.moves_left > 0);
            undo_action.set_enabled (game_view.game.can_undo);
            redo_action.set_enabled (game_view.game.can_redo);
        }

        moves_label.set_text ("%2u".printf (game_view.game.moves_left));
    }

    private void theme_changed_cb (Gtk.ComboBox widget)
    {
        Gtk.TreeIter iter;
        widget.get_active_iter (out iter);
        string theme;
        widget.model.get (iter, 1, out theme);
        settings.set_string ("tileset", theme);
    }

    private void conf_value_changed_cb (Settings settings, string key)
    {
        if (key == "tileset")
        {
            var theme = settings.get_string ("tileset");
            game_view.theme = Path.build_filename (DATA_DIRECTORY, "themes", theme);
        }
        else if (key == "bgcolour")
        {
            game_view.set_background (settings.get_string ("bgcolour"));
        }
        else if (key == "mapset")
        {
            /* Prompt user if already made a move */
            if (game_view.game.started)
            {
                var dialog = new Gtk.MessageDialog (window,
                                                    Gtk.DialogFlags.MODAL,
                                                    Gtk.MessageType.QUESTION,
                                                    Gtk.ButtonsType.NONE,
                                                    "%s", _("Do you want to start a new game with this map?"));
                dialog.format_secondary_text (_("If you continue playing the next game will use the new map."));
                dialog.add_buttons (_("_Continue playing"), Gtk.ResponseType.REJECT,
                                    _("Use _new map"), Gtk.ResponseType.ACCEPT,
                                    null);
                dialog.set_default_response (Gtk.ResponseType.ACCEPT);
                var response = dialog.run ();
                if (response == Gtk.ResponseType.ACCEPT)
                    new_game ();
                dialog.destroy ();
            }
            else
                new_game ();
        }
    }

    private bool view_button_press_event (Gtk.Widget widget, Gdk.EventButton event)
    {
        /* Cancel pause on click */
        if (game_view.game.paused)
        {
            game_view.game.paused = false;
            return true;
        }

        return false;
    }

    private void background_changed_cb (Gtk.ColorButton widget)
    {
        Gdk.RGBA colour;
        /* See https://bugzilla.gnome.org/show_bug.cgi?id=669386 */
        Gtk.color_button_get_rgba (widget, out colour);
        settings.set_string ("bgcolour", "#%04x%04x%04x".printf ((int) (colour.red * 65536 + 0.5), (int) (colour.green * 65536 + 0.5), (int) (colour.blue * 65536 + 0.5)));
    }

    private void map_changed_cb (Gtk.ComboBox widget)
    {
        settings.set_string ("mapset", maps.nth_data (widget.active).name);
    }

    private void moved_cb ()
    {
        update_ui ();

        if (game_view.game.complete)
        {
            var seconds = (int) (game_view.game.elapsed + 0.5);

            var p = highscores.add_time_score ((seconds / 60) * 1.0 + (seconds % 60) / 100.0);
            var scores_dialog = new GnomeGamesSupport.ScoresDialog (window, highscores, _("Mahjongg Scores"));
            scores_dialog.set_category_description (_("Layout:"));
            var title = _("Puzzle solved!");
            var message = _("You didn't make the top ten, better luck next time.");
            if (p == 1)
                message = _("Your score is the best!");
            else if (p > 1)
                message = _("Your score has made the top ten.");
            scores_dialog.set_message ("<b>%s</b>\n\n%s".printf (title, message));
            scores_dialog.set_buttons (GnomeGamesSupport.ScoresButtons.QUIT_BUTTON | GnomeGamesSupport.ScoresButtons.NEW_GAME_BUTTON);
            if (p > 0)
                scores_dialog.set_hilight (p);

            switch (scores_dialog.run ())
            {
            case Gtk.ResponseType.REJECT:
                window.destroy ();
                break;
            default:
                new_game ();
                break;
            }
            scores_dialog.destroy ();
        }
        else if (!game_view.game.can_move)
        {
            var dialog = new Gtk.MessageDialog (window, Gtk.DialogFlags.MODAL | Gtk.DialogFlags.DESTROY_WITH_PARENT,
                                                Gtk.MessageType.INFO,
                                                Gtk.ButtonsType.NONE,
                                                "%s", _("There are no more moves."));
            dialog.format_secondary_text (_("Each puzzle has at least one solution.  You can undo your moves and try and find the solution for a time penalty, restart this game or start an new one."));
            dialog.add_buttons (Gtk.Stock.UNDO, Gtk.ResponseType.REJECT,
                                _("_Restart"), Gtk.ResponseType.CANCEL,
                                _("_New game"), Gtk.ResponseType.ACCEPT);

            dialog.set_default_response (Gtk.ResponseType.ACCEPT);
            switch (dialog.run ())
            {
            case Gtk.ResponseType.REJECT:
                undo_cb ();
                break;
            case Gtk.ResponseType.CANCEL:
                restart_game ();
                break;
            default:
            case Gtk.ResponseType.ACCEPT:
                new_game ();
                break;
            }
            dialog.destroy ();
        }
    }

    private void preferences_cb ()
    {
        if (preferences_dialog != null)
        {
            preferences_dialog.present ();
            return;
        }

        preferences_dialog = new Gtk.Dialog.with_buttons (_("Mahjongg Preferences"),
                                                   window,
                                                   Gtk.DialogFlags.DESTROY_WITH_PARENT,
                                                   Gtk.Stock.CLOSE,
                                                   Gtk.ResponseType.CLOSE, null);
        preferences_dialog.set_border_width (5);
        var dialog_content_area = (Gtk.Box) preferences_dialog.get_content_area ();
        dialog_content_area.set_spacing (2);
        preferences_dialog.set_resizable (false);
        preferences_dialog.set_default_response (Gtk.ResponseType.CLOSE);
        preferences_dialog.response.connect (preferences_dialog_response_cb);

        var grid = new Gtk.Grid ();
        grid.border_width = 5;
        grid.set_row_spacing (6);
        grid.set_column_spacing (18);

        var label = new Gtk.Label.with_mnemonic (_("_Theme:"));
        label.set_alignment (0, 0.5f);
        grid.attach (label, 0, 0, 1, 1);

        var themes = load_themes ();
        var theme_combo = new Gtk.ComboBox ();
        var theme_store = new Gtk.ListStore (2, typeof (string), typeof (string));
        theme_combo.model = theme_store;
        var renderer = new Gtk.CellRendererText ();
        theme_combo.pack_start (renderer, true);
        theme_combo.add_attribute (renderer, "text", 0);
        foreach (var theme in themes)
        {
            var tokens = theme.split (".", -1);
            var name = tokens[0];

            Gtk.TreeIter iter;
            theme_store.append (out iter);
            theme_store.set (iter, 0, name, 1, theme, -1);

            if (theme == settings.get_string ("tileset"))
                theme_combo.set_active_iter (iter);
        }
        theme_combo.changed.connect (theme_changed_cb);
        theme_combo.set_hexpand (true);
        grid.attach (theme_combo, 1, 0, 1, 1);
        label.set_mnemonic_widget (theme_combo);

        label = new Gtk.Label.with_mnemonic (_("_Layout:"));
        label.set_alignment (0, 0.5f);
        grid.attach (label, 0, 1, 1, 1);

        var map_combo = new Gtk.ComboBox ();
        var map_store = new Gtk.ListStore (2, typeof (string), typeof (string));
        map_combo.model = map_store;
        renderer = new Gtk.CellRendererText ();
        map_combo.pack_start (renderer, true);
        map_combo.add_attribute (renderer, "text", 0);
        foreach (var map in maps)
        {
            var display_name = dpgettext2 (null, "mahjongg map name", map.name);

            Gtk.TreeIter iter;
            map_store.append (out iter);
            map_store.set (iter, 0, display_name, 1, map, -1);

            if (settings.get_string ("mapset") == map.name)
                map_combo.set_active_iter (iter);
        }
        map_combo.changed.connect (map_changed_cb);
        map_combo.set_hexpand (true);
        grid.attach (map_combo, 1, 1, 1, 1);
        label.set_mnemonic_widget (map_combo);

        label = new Gtk.Label.with_mnemonic (_("_Background color:"));
        label.set_alignment (0, 0.5f);
        grid.attach (label, 0, 2, 1, 1);

        var widget = new Gtk.ColorButton ();
        widget.set_rgba (game_view.background_color);
        widget.color_set.connect (background_changed_cb);
        widget.set_hexpand (true);
        grid.attach (widget, 1, 2, 1, 1);
        label.set_mnemonic_widget (widget);

        dialog_content_area.pack_start (grid, true, true, 0);

        preferences_dialog.show_all ();
    }

    private void preferences_dialog_response_cb (Gtk.Dialog dialog, int response)
    {
        preferences_dialog.destroy ();
        preferences_dialog = null;
    }

    private List<string> load_themes ()
    {
        List<string> themes = null;

        Dir dir;
        try
        {
            dir = Dir.open (Path.build_filename (DATA_DIRECTORY, "themes"));
        }
        catch (FileError e)
        {
            return themes;
        }

        while (true)
        {
            var s = dir.read_name ();
            if (s == null)
                break;

            if (s.has_suffix (".xpm") || s.has_suffix (".svg") || s.has_suffix (".gif") ||
                s.has_suffix (".png") || s.has_suffix (".jpg") || s.has_suffix (".xbm"))
                themes.append (s);
        }

        return themes;
    }

    private void hint_cb ()
    {
        var matches = game_view.game.find_matches (game_view.game.selected_tile);
        var n_matches = matches.length ();

        /* No match, just flash the selected tile */
        if (n_matches == 0)
        {
            if (game_view.game.selected_tile == null)
                return;
            game_view.game.set_hint (game_view.game.selected_tile, null);
        }
        else
        {
            var n = Random.int_range (0, (int) n_matches);
            var match = matches.nth_data (n);
            game_view.game.set_hint (match.tile0, match.tile1);
        }

        update_ui ();
    }

    private void about_cb ()
    {
        string[] authors =
        {
            _("Main game:"),
            "Francisco Bustamante",
            "Max Watson",
            "Heinz Hempe",
            "Michael Meeks",
            "Philippe Chavin",
            "Callum McKenzie",
            "Robert Ancell",
            "",
            _("Maps:"),
            "Rexford Newbould",
            "Krzysztof Foltman",
            null
        };

        string[] artists =
        {
            _("Tiles:"),
            "Jonathan Buzzard",
            "Jim Evans",
            "Richard Hoelscher",
            "Gonzalo Odiard",
            "Max Watson",
            null
        };

        string[] documenters =
        {
            "Tiffany Antopolski",
            "Chris Beiser",
            null
        };

        Gtk.show_about_dialog (window,
                               "program-name", _("Mahjongg"),
                               "version", VERSION,
                               "comments",
                               _("A matching game played with Mahjongg tiles.\n\nMahjongg is a part of GNOME Games."),
                               "copyright", "Copyright \xc2\xa9 1998-2008 Free Software Foundation, Inc.",
                               "license", GnomeGamesSupport.get_license (_("Mahjongg")),
                               "wrap-license", true,
                               "authors", authors,
                               "artists", artists,
                               "documenters", documenters,
                               "translator-credits", _("translator-credits"),
                               "logo-icon-name", "gnome-mahjongg",
                               "website", "http://www.gnome.org/projects/gnome-games",
                               "website-label", _("GNOME Games web site"),
                               null);
    }

    private void pause_cb ()
    {
        game_view.game.paused = !game_view.game.paused;
        game_view.game.set_hint (null, null);
        game_view.game.selected_tile = null;
        if (game_view.game.paused)
        {
            pause_button.icon_name = "media-playback-start";
            pause_button.label = _("Res_ume");
        }
        else
        {
            pause_button.icon_name = "media-playback-pause";
            pause_button.label = _("_Pause");
        }

        update_ui ();
    }

    private void scores_cb ()
    {
        var map_scores_dialog = new GnomeGamesSupport.ScoresDialog (window, highscores, _("Mahjongg Scores"));
        map_scores_dialog.set_category_description (_("Layout:"));
        map_scores_dialog.run ();
        map_scores_dialog.destroy ();
    }

    private void new_game_cb ()
    {
        new_game ();
    }

    private void restart_game_cb ()
    {
        game_view.game.reset ();
        game_view.queue_draw ();
    }

    private void quit_cb ()
    {
        window.destroy ();
    }

    private void redo_cb ()
    {
        if (game_view.game.paused)
            return;

        game_view.game.redo ();
        update_ui ();
    }

    private void undo_cb ()
    {
        game_view.game.undo ();
        update_ui ();
    }

    private void restart_game ()
    {
        game_view.game.reset ();
        update_ui ();
    }

    private void new_game ()
    {
        Map? map = null;
        foreach (var m in maps)
        {
            if (m.name == settings.get_string ("mapset"))
            {
                map = m;
                break;
            }
        }
        if (map == null)
            map = maps.nth_data (0);

        game_view.game = new Game (map);
        game_view.game.moved.connect (moved_cb);
        game_view.game.tick.connect (tick_cb);
        highscores.set_category (game_view.game.map.score_name);

        /* Set window title */
        var display_name = dpgettext2 (null, "mahjongg map name", game_view.game.map.name);
        /* Translators: This is the window title for Mahjongg which contains the map name, e.g. 'Mahjongg - Red Dragon' */
        window.set_title (_("Mahjongg - %s").printf (display_name));

        update_ui ();
    }

    private void tick_cb ()
    {
        var elapsed = 0;
        if (game_view.game != null)
            elapsed = (int) (game_view.game.elapsed + 0.5);
        var hours = elapsed / 3600;
        var minutes = (elapsed - hours * 3600) / 60;
        var seconds = elapsed - hours * 3600 - minutes * 60;
        clock_label.set_text ("%s: %02d:%02d:%02d".printf (_("Time"), hours, minutes, seconds));
    }

    private void help_cb ()
    {
        try
        {
            Gtk.show_uri (window.get_screen (), "help:gnome-mahjongg", Gtk.get_current_event_time ());
        }
        catch (Error e)
        {
            warning ("Failed to show help: %s", e.message);
        }
    }

    private const GLib.ActionEntry[] action_entries =
    {
        { "new-game",      new_game_cb     },
        { "undo",          undo_cb         },
        { "redo",          redo_cb         },
        { "hint",          hint_cb         },
        { "pause",         pause_cb        },
        { "restart-game",  restart_game_cb },
        { "scores",        scores_cb       },
        { "preferences",   preferences_cb  },
        { "help",          help_cb         },
        { "about",         about_cb        },
        { "quit",          quit_cb         }
    };

    private void load_maps ()
    {
        maps = null;

        /* Add the builtin map */
        maps.append (new Map.builtin ());

        Dir dir;
        try
        {
            dir = Dir.open (Path.build_filename (DATA_DIRECTORY, "maps"));
        }
        catch (FileError e)
        {
            return;
        }
        while (true)
        {
            var filename = dir.read_name ();
            if (filename == null)
                break;

            if (!filename.has_suffix (".map"))
                continue;

            var loader = new MapLoader ();
            try
            {
                loader.load (filename);
            }
            catch (Error e)
            {
                warning ("Could not load map %s: %s\n", filename, e.message);
                continue;
            }
            foreach (var map in loader.maps)
                maps.append (map);
        }
    }

    public static int main (string[] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        GnomeGamesSupport.scores_startup ();

        Gtk.init (ref args);

        var context = new OptionContext ("");
        context.set_translation_domain (GETTEXT_PACKAGE);
        context.add_group (Gtk.get_option_group (true));

        try
        {
            context.parse (ref args);
        }
        catch (Error e)
        {
            stdout.printf ("%s\n", e.message);
            return Posix.EXIT_FAILURE;
        }

        Environment.set_application_name (_("Mahjongg"));
        Gtk.Window.set_default_icon_name ("gnome-mahjongg");

        var app = new Mahjongg ();
        var result = app.run ();

        Settings.sync();

        return result;
    }
}
