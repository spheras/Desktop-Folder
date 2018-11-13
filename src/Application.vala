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

/**
 * @class
 * The Main Application
 */
public class DesktopFolderApp : Gtk.Application {

/** File Monitor of desktop folder */
private FileMonitor monitor = null;

/** The volume monitor */
private GLib.VolumeMonitor volume_monitor = null;

/** schema settings */
private GLib.Settings settings              = null;
private const string SHOW_DESKTOPFOLDER_KEY = "show-desktopfolder";

/** List of folder owned by the application */
private DesktopFolder.DesktopManager desktop       = null;
private List <DesktopFolder.FolderManager> folders = new List <DesktopFolder.FolderManager> ();
private List <DesktopFolder.NoteManager> notes     = new List <DesktopFolder.NoteManager> ();
private List <DesktopFolder.PhotoManager> photos   = new List <DesktopFolder.PhotoManager> ();
private int current_id = 0;

construct {
	/* Needed by Glib.Application */
	this.application_id = DesktopFolder.APP_ID; // Ensures an unique instance.
	this.flags          = ApplicationFlags.FLAGS_NONE;

	/* Needed by Granite.Application */
	/*
	   this.program_name = _(DesktopFolder.APP_TITLE);
	   this.exec_name = DesktopFolder.APP_NAME;
	   this.build_version = DesktopFolder.VERSION;
	 */
}

/**
 * @constructor
 */
public DesktopFolderApp () {
	Object (application_id: "com.github.spheras.desktopfolder",
	        flags : ApplicationFlags.FLAGS_NONE);
}

/**
 * @name get_fake_desktop
 * @description return the fake desktop manager
 * @return {DesktopFolder.DesktopManager} the fake desktop manager
 */
public DesktopFolder.DesktopManager get_fake_desktop () {
	return this.desktop;
}

/**
 * @name activate
 * @override
 * @description activate life cycle
 */
protected override void activate () {
	base.activate ();
	debug ("activate event");
	// we'll init the app in the activate event
	init ();
}

/**
 * @name startup
 * @override
 * @description startup life cycle
 */
public override void startup () {
	base.startup ();
	debug ("startup event");
}

/**
 * @name get_next_id
 * @description return the next valid id for a window
 * @return {string} the next valid id
 */
public string get_next_id () {
	this.current_id++;
	return "id%d".printf (this.current_id);
}

/**
 * @name init
 * @description initialization of the application
 */
private void init () {
	// only one app at a time
	if (get_windows ().length () > 0) {
		get_windows ().data.present ();
		return;
	}

	// define our settings schema
	settings = new GLib.Settings ("com.github.spheras.desktopfolder");

	// Connect to show-desktopfolder key
	settings.changed[SHOW_DESKTOPFOLDER_KEY].connect (on_show_desktopfolder_changed);
	on_show_desktopfolder_changed ();

	create_shortcut ();

	// we need the app folder (desktop folder)
	var desktopFolder = File.new_for_path (DesktopFolderApp.get_app_folder ());
	if (!desktopFolder.query_exists ()) {
		DirUtils.create (DesktopFolderApp.get_app_folder (), 0755);
	}

	// initializing the clipboard manager
	DesktopFolder.Clipboard.ClipboardManager.get_for_display ();

	// providing css style
	var provider = new Gtk.CssProvider ();
	provider.load_from_resource ("com/github/spheras/desktopfolder/Application.css");
	Gtk.StyleContext.add_provider_for_screen (Gdk.Screen.get_default (), provider,
	                                          Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

	// quit action
	/*
	   var quit_action = new SimpleAction ("quit", null);
	   add_action (quit_action);
	   add_accelerator ("<Control>q", "app.quit", null);
	   quit_action.activate.connect (() => {
	    if (app_window != null) {
	        app_window.destroy ();
	    }
	   });
	 */

	// we start creating the folders found at the desktop folder
	this.sync_folders_and_notes ();

	this.monitor_desktop ();

	// Listening to size change events
	Gdk.Screen.get_default ().size_changed.connect (this.on_screen_size_changed);
	Gdk.Screen.get_default ().composited_changed.connect (this.on_screen_size_changed);
	Gdk.Screen.get_default ().monitors_changed.connect (this.on_screen_size_changed);

	// Listening mount change events
	this.volume_monitor = VolumeMonitor.get ();
	volume_monitor.mount_changed.connect ((mount) => {
			this.on_mount_changed ();
		});
	this.volume_monitor.volume_changed.connect ((volume) => {
			this.on_mount_changed ();
		});
}

/**
 * @name on_show_desktopfolder_changed
 * @description detect when desktopfolder key is toggled
 */
private void on_show_desktopfolder_changed () {
	bool show_desktopfolder = settings.get_boolean (SHOW_DESKTOPFOLDER_KEY);
	if (!show_desktopfolder) {
		// requested to no longer show the desktop so let's gracefully quit
		this.quit ();
	}
}

/**
 * @name on_mount_changed
 * @description event to detect when the mount file system has been changed, probably we need to recheck files existence
 */
public void on_mount_changed () {
	debug ("MOUNT FILE SYSTEM CHANGED");
	for (int i = 0; i < this.folders.length (); i++) {
		this.folders.nth_data (i).on_mount_changed ();
	}
	if (this.desktop != null) {
		this.desktop.on_mount_changed ();
	}
}

/**
 * @name on_screen_size_changed
 * @description detecting screen size changes
 */
public void on_screen_size_changed () {
	debug ("SCREEN SIZE CHANGED!");
	Gdk.Screen screen = Gdk.Screen.get_default ();
	if (this.desktop != null) {
		this.desktop.on_screen_size_changed (screen);
	}
	for (int i = 0; i < this.folders.length (); i++) {
		this.folders.nth_data (i).on_screen_size_changed (screen);
	}
	for (int i = 0; i < this.notes.length (); i++) {
		this.notes.nth_data (i).on_screen_size_changed (screen);
	}
	for (int i = 0; i < this.photos.length (); i++) {
		this.photos.nth_data (i).on_screen_size_changed (screen);
	}
}

/** the desktop folder name */
public static string desktop_folder_name = "Desktop";

/**
 * @name get_app_folder
 * @description return the path where the app search folders to be created (the desktop folder)
 * @return string the absolute path directory
 */
public static string get_app_folder () {
	return Environment.get_home_dir () + "/" + DesktopFolderApp.desktop_folder_name;
}

/**
 * @name check_fake_desktop
 * @description check if the fake desktop must be showed or not to create it
 */
private void check_fake_desktop () {
	string[]      keys  = settings.list_keys ();
	bool found = false;
	for (int i = 0; i < keys.length; i++) {
		string key = keys[i];
		if (key == "desktop-panel") {
			found = true;
			break;
		}
	}
	bool desktop_panel = false;
	if (found) {
		desktop_panel = settings.get_boolean ("desktop-panel");
	}

	if (desktop_panel && this.desktop == null) {
		this.desktop = new DesktopFolder.DesktopManager (this);
		for (int i = 0; i < this.folders.length (); i++) {
			var fm = this.folders.nth (i).data;
			fm.reopen ();
		}
		for (int i = 0; i < this.notes.length (); i++) {
			var fm = this.notes.nth (i).data;
			fm.reopen ();
		}
		for (int i = 0; i < this.photos.length (); i++) {
			var fm = this.photos.nth (i).data;
			fm.reopen ();
		}

	} else if (!desktop_panel && this.desktop != null) {
		this.desktop.close ();
		this.desktop = null;
	}
}

/**
 * @name sync_folders_and_notes
 * @description create as many folder and note windows as the desktop folder and note founds
 */
private void sync_folders_and_notes () {
	try {
		check_fake_desktop ();

		var base_path  = DesktopFolderApp.get_app_folder ();
		var directory  = File.new_for_path (base_path);
		var enumerator = directory.enumerate_children (FileAttribute.STANDARD_NAME, 0);

		FileInfo file_info;
		List <DesktopFolder.FolderManager> updated_folder_list = new List <DesktopFolder.FolderManager> ();
		List <DesktopFolder.NoteManager>   updated_note_list   = new List <DesktopFolder.NoteManager> ();
		List <DesktopFolder.PhotoManager>  updated_photo_list  = new List <DesktopFolder.PhotoManager> ();
		int totalFolders = 0;
		int totalNotes   = 0;
		int totalPhotos  = 0;
		while ((file_info = enumerator.next_file ()) != null) {
			string name   = file_info.get_name ();
			File file   = File.new_for_commandline_arg (base_path + "/" + name);
			FileType type   = file.query_file_type (FileQueryInfoFlags.NONE);

			File nopanel    = File.new_for_commandline_arg (base_path + "/" + name + "/" + DesktopFolder.PANEL_BLACKLIST_FILE);
			File panel_flag = File.new_for_commandline_arg (base_path + "/" + name + "/" + DesktopFolder.FOLDER_SETTINGS_FILE);
			if (type == FileType.DIRECTORY) {

				// Is this folder already known about?
				DesktopFolder.FolderManager fm = this.find_folder_by_name (name);

				if (nopanel.query_exists () || !panel_flag.query_exists ()) {
					if (fm != null) {
						// This folder doesn't want to be a panel anymore
						// (this check might be pointless however because it's already done in FolderManager's sync)
						fm.close ();
					}
					// This folder doesn't want to be a panel, let's skip it
					continue;
				}

				totalFolders++;

				if (fm == null) {
					// No, it's a new folder
					fm = new DesktopFolder.FolderManager (this, name);
				} else {
					this.folders.remove (fm);
				}
				updated_folder_list.append (fm);
			} else {
				string basename = file.get_basename ();
				int index    = basename.last_index_of (".", 0);
				if (index > 0) {
					string ext       = basename.substring (index + 1);
					string file_name = basename.substring (0, index);
					if (ext == DesktopFolder.OLD_NOTE_EXTENSION || ext == DesktopFolder.NEW_NOTE_EXTENSION) {
						totalNotes++;

						// Is this note already known about?
						DesktopFolder.NoteManager nm = this.find_note_by_name (file_name);

						if (nm == null) {
							// No, it's a new note
							nm = new DesktopFolder.NoteManager (this, basename.substring (0, index), file);
						} else {
							this.notes.remove (nm);
						}
						if (nm.is_valid ()) {
							updated_note_list.append (nm);
						}
					} else if (ext == DesktopFolder.OLD_PHOTO_EXTENSION || ext == DesktopFolder.NEW_PHOTO_EXTENSION) {
						totalPhotos++;

						// Is this photo already known about?
						DesktopFolder.PhotoManager pm = this.find_photo_by_name (file_name);

						if (pm == null) {
							// No, it's a new photo
							pm = new DesktopFolder.PhotoManager (this, basename.substring (0, index), file);
						} else {
							this.photos.remove (pm);
						}
						if (pm.is_valid ()) {
							updated_photo_list.append (pm);
						}
					}
				}
				// nothing
				// we only deal with folders to be shown
			}
		}

		// finally we close any other not existent folder
		while (this.folders.length () > 0) {
			DesktopFolder.FolderManager fm = this.folders.nth (0).data;
			fm.close ();
			this.folders.remove (fm);
		}
		this.folders = updated_folder_list.copy ();

		// finally we close any other not existent note
		while (this.notes.length () > 0) {
			DesktopFolder.NoteManager nm = this.notes.nth (0).data;
			nm.close ();
			this.notes.remove (nm);
		}
		this.notes = updated_note_list.copy ();

		// finally we close any other not existent photo
		while (this.photos.length () > 0) {
			DesktopFolder.PhotoManager pm = this.photos.nth (0).data;
			pm.close ();
			this.photos.remove (pm);
		}
		this.photos = updated_photo_list.copy ();

		// by default, we create at least one folder if set by settings
		if (totalFolders == 0 && totalPhotos == 0 && totalNotes == 0 && this.desktop == null) {
			string first_panel_path         = DesktopFolderApp.get_app_folder () + "/" + DesktopFolder.Lang.APP_FIRST_PANEL;
			DirUtils.create (first_panel_path, 0755);
			File first_settings_file        = File.new_for_path (first_panel_path + "/.desktopfolder");
			DesktopFolder.FolderSettings fs = new DesktopFolder.FolderSettings (DesktopFolder.Lang.APP_FIRST_PANEL);
			fs.save_to_file (first_settings_file);

			this.sync_folders_and_notes ();
		}
	} catch (Error e) {
		// error! ??
		stderr.printf ("Error: %s\n", e.message);
		DesktopFolder.Util.show_error_dialog ("Error", e.message);
	}
}

/**
 * @name count_widgets
 * @description return the amount of widgets existing
 * @return {int} the total widgets currently shown
 */
public uint count_widgets () {
	return this.photos.length () + this.notes.length () + this.folders.length ();
}

/**
 * @name find_folder_by_name
 * @description find a foldermanager managed by its name
 * @param string folder_name the name of the folder to find
 * @return FolderManager the Folder found or null if none
 */
private DesktopFolder.FolderManager ? find_folder_by_name (string folder_name) {
	for (int i = 0; i < this.folders.length (); i++) {
		DesktopFolder.FolderManager fm = this.folders.nth (i).data;
		if (fm.get_folder_name () == folder_name) {
			return fm;
		}
	}
	return null;
}

/**
 * @name find_note_by_name
 * @description find a notemanager managed by its name
 * @param string note_name the name of the note to find
 * @return NoteManager the Note found or null if none
 */
private DesktopFolder.NoteManager ? find_note_by_name (string note_name) {
	for (int i = 0; i < this.notes.length (); i++) {
		DesktopFolder.NoteManager nm = this.notes.nth (i).data;
		if (nm.get_note_name () == note_name) {
			return nm;
		}
	}
	return null;
}

/**
 * @name find_photo_by_name
 * @description find a photomanager managed by its name
 * @param string photo_name the name of the photo to find
 * @return PhotoManager the Photo found or null if none
 */
private DesktopFolder.PhotoManager ? find_photo_by_name (string photo_name) {
	for (int i = 0; i < this.photos.length (); i++) {
		DesktopFolder.PhotoManager nm = this.photos.nth (i).data;
		if (nm.get_photo_name () == photo_name) {
			return nm;
		}
	}
	return null;
}

/**
 * @name exist_manager
 * @description check if the folder_name is being monitored or not
 * @return bool true->yes, it is being monitored
 */
public bool exist_manager (string folder_name) {
	for (int i = 0; i < this.folders.length (); i++) {
		DesktopFolder.FolderManager fm = this.folders.nth (i).data;
		if (fm.get_folder_name () == folder_name) {
			return true;
		}
	}
	return false;
}

/**
 * @name monitor_desktop
 * @description monitor the desktop folder
 */
private void monitor_desktop () {
	try {
		if (this.monitor != null) {
			// if we have an existing monitor, we cancel it before to monitor again
			this.monitor.cancel ();
		}
		var basePath  = DesktopFolderApp.get_app_folder ();
		File directory = File.new_for_path (basePath);
		this.monitor            = directory.monitor_directory (FileMonitorFlags.SEND_MOVED, null);
		this.monitor.rate_limit = 100;
		debug ("Monitoring: %s\n", directory.get_path ());
		this.monitor.changed.connect (this.desktop_changed);
	} catch (Error e) {
		stderr.printf ("Error: %s\n", e.message);
		DesktopFolder.Util.show_error_dialog ("Error", e.message);
	}
}

/**
 * @name desktop_changed
 * @description we received an event of the monitor that indicates a change
 * @see changed signal of FileMonitor (https://valadoc.org/gio-2.0/GLib.FileMonitor.changed.html)
 */
private void desktop_changed (GLib.File src, GLib.File ? dest, FileMonitorEvent event) {
	// something changed at the desktop folder
	bool flagNote   = false;
	bool flagPhoto  = false;

	string basename = src.get_basename ();
	int index    = basename.last_index_of (".", 0);
	if (index > 0) {
		string ext = basename.substring (index + 1);
		if (ext == DesktopFolder.OLD_NOTE_EXTENSION || ext == DesktopFolder.NEW_NOTE_EXTENSION) {
			flagNote = true;
		} else if (ext == DesktopFolder.OLD_PHOTO_EXTENSION || ext == DesktopFolder.NEW_PHOTO_EXTENSION) {
			flagPhoto = true;
		}
	}

	// new content inside
	var file_type = src.query_file_type (FileQueryInfoFlags.NONE);
	if (flagNote || flagPhoto || file_type == FileType.DIRECTORY || !src.query_exists ()) {
		// debug("Desktop - Change Detected");
		// new directory or removed, we need to synchronize
		// removed directory
		this.sync_folders_and_notes ();
	}
}

/**
 * @name clear_all
 * @description close all the folders launched
 */
protected void clear_all () {
	for (int i = 0; i < this.folders.length (); i++) {
		DesktopFolder.FolderManager fm = this.folders.nth (i).data;
		fm.close ();
	}
	this.folders = new List <DesktopFolder.FolderManager> ();
}

/**
 * Main application
 */
public static int main (string[] args) {
	if (args.length > 1 && args[1].up () == DesktopFolder.PARAM_SHOW_DESKTOP.up ()) {
		minimize_all (args);
		return 0;
	}
	if (args.length > 1 && (args[1].up () == DesktopFolder.PARAM_SHOW_VERSION.up () || args[1].up () == "--" + DesktopFolder.PARAM_SHOW_VERSION.up ())) {
		stdout.printf ("Desktop Folder. Version %s\n", DesktopFolder.VERSION);
		return 0;
	} else {
		var app = new DesktopFolderApp ();
		if (args.length > 1) {
			DesktopFolderApp.desktop_folder_name = args[1];
		}
		return app.run ();
	}
}

/**
 * @name minimize_all
 * @description minimize all windows
 * @param args string[] the list of args to initialize Gdk
 */
private static void minimize_all (string[] args) {
	Gtk.init (ref args);

	bool flagShowingDesktop = true;

	// Help wanted: Need to check manually if we are showing desktop
	// because screen.get_showing_desktop (); always return false
	unowned Wnck.Screen screen = Wnck.Screen.get_default ();
	while (Gtk.events_pending ()) {
		Gtk.main_iteration ();
	}
	unowned List <Wnck.Window> windows = screen.get_windows ();
	foreach (Wnck.Window w in windows) {
		if (!w.is_minimized () && w.get_window_type () == Wnck.WindowType.NORMAL) {
			flagShowingDesktop = false;
		}
	}


	// unowned Wnck.Screen screen = Wnck.Screen.get_default ();
	bool show = !flagShowingDesktop; // !screen.get_showing_desktop ();
	screen.toggle_showing_desktop (show);

	/*
	    string sshow="show: %s".printf(show?"true":"false");
	        // The MessageDialog
	                Gtk.MessageDialog msg = new Gtk.MessageDialog (null, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING, Gtk.ButtonsType.OK_CANCEL, "show:"+sshow);
	                        msg.response.connect ((response_id) => {
	                        switch (response_id) {
	                                case Gtk.ResponseType.OK:
	                                        stdout.puts ("Ok\n");
	                                        break;
	                                case Gtk.ResponseType.CANCEL:
	                                        stdout.puts ("Cancel\n");
	                                        break;
	                                case Gtk.ResponseType.DELETE_EVENT:
	                                        stdout.puts ("Delete\n");
	                                        break;
	                        }
	                        msg.destroy();
	                });
	                msg.show ();
	        Gtk.main ();
	 */

	/**
	   "manual style"
	   Wnck.Screen screen = Wnck.Screen.get_default ();
	   while (Gtk.events_pending ()) {
	    Gtk.main_iteration ();
	   }
	   unowned List <Wnck.Window> windows = screen.get_windows ();
	   foreach (Wnck.Window w in windows) {
	    Wnck.Application window_app = w.get_application ();
	    string           name       = window_app.get_name ();
	    // debug("app name:%s",name);
	    if (name != DesktopFolder.APP_ID) {
	        w.minimize ();
	    }
	   }
	 */
}

/**
 * @name create_shortcut
 * @description create a short cut SUPER-D at the system shortcuts to minimize all windows
 */
private static void create_shortcut () {
	string path                        = "/usr/bin/"; // we expect to have the command at the path
	Pantheon.Keyboard.Shortcuts.CustomShortcutSettings.init ();
	var shortcut                    = new Pantheon.Keyboard.Shortcuts.Shortcut (100, Gdk.ModifierType.SUPER_MASK);
	string command_conflict            = "";
	string relocatable_schema_conflict = "";
	if (!Pantheon.Keyboard.Shortcuts.CustomShortcutSettings.shortcut_conflicts (shortcut, out command_conflict,
	                                                                            out relocatable_schema_conflict)) {

		debug ("registering hotkey!");
		var relocatable_schema = Pantheon.Keyboard.Shortcuts.CustomShortcutSettings.create_shortcut ();
		Pantheon.Keyboard.Shortcuts.CustomShortcutSettings.edit_command ((string) relocatable_schema,
		                                                                 path + "com.github.spheras.desktopfolder " + DesktopFolder.PARAM_SHOW_DESKTOP);
		Pantheon.Keyboard.Shortcuts.CustomShortcutSettings.edit_shortcut ((string) relocatable_schema,
		                                                                  shortcut.to_gsettings ());
	}
}

}
