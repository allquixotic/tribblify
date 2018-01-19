/* -*- Mode: C; indent-tabs-mode: t; c-basic-offset: 4; tab-width: 4 -*- */
/*
 * tribblify.vala
 * Copyright (C) Sean McNamara 2012-2018 <smcnam@gmail.com>
 * 
 * tribblify is free software: you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published
 * by the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * tribblify is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using GLib;
using Gst;
using Gst.Tags;
using Gdk;
using Wnck;

extern void exit(int exit_code);

public class Main : GLib.Object 
{
	private MainLoop? ml = null;
	
	//For libwnck
	private Wnck.Screen? screen = null;

	//For gstreamer
	private Pipeline? pipe = null;
	private Gst.Bus?  bus = null;
	private Element?  pulsesrc = null;
	private Element?  lamemp3enc = null;
	private Element?  shout2send = null;
	private Element?  queue = null;

	//For command line argument processing
	private OptionContext? ctxt;
	
	//gstreamer tunables
	private static string? protocol = "icecast";
	private static string? ip = "127.0.0.1";
	private static int port = 8192;
	private static string? password = "";
	private static string? mount = "/listen.mp3";
	private static int bitrate = 128;
	private static string? device = "output.monitor";

	//Wnck tunables
	private static int tagpoll = 4000;
	private static string? wmClass = "spotify";
	private static int screenId = -1;

	//For updating tags
	private string? curr_artist  = null;
	private string? curr_title   = null;

	const OptionEntry[] entries =
	{
		{ "protocol",       'p',  0, OptionArg.STRING, ref protocol, "Protocol: shoutcast or icecast",   "proto_name"},
		{ "shout-ip",       's',  0, OptionArg.STRING, ref ip,       "Shoutcast/icecast IP/hostname",    "hostname"},
		{ "shout-port",     'o',  0, OptionArg.INT,    ref port,     "Shoutcast/icecast port",           "uint"},
		{ "shout-password", 'd',  0, OptionArg.STRING, ref password, "Shoutcast/icecast password",       "password"},
		{ "mount",          'm',  0, OptionArg.STRING, ref mount,    "Icecast mount point",              "mount"},
		{ "bitrate",        'b',  0, OptionArg.INT,    ref bitrate,  "MP3 CBR bitrate",                  "uint"},
		{ "device",         'i',  0, OptionArg.STRING, ref device,   "PulseAudio source",                "device"},
		{ "wmClass",        'z',  0, OptionArg.STRING, ref wmClass,  "WM_CLASS group/class name of Spotify",              "wmClass"},
		{ "screenId",       'r',  0, OptionArg.INT,    ref screenId,  "Xorg Screen ID",                  "uint"},
		{ "tagpoll",        't',  0, OptionArg.INT,    ref tagpoll,  "Frequency of tag polling in msec", "uint"},
		{null}
	};

	public Main(string[] args)
	{	
		Gdk.init(ref args);
		ml = new MainLoop(null, false);
		
		parse_opts(args);

		//Create connection to Xorg Screen via Wnck
		screen = Wnck.Screen.get_default();
		if(screen == null) {
			stdout.printf("Error: Unable to open Xorg display! May need to set DISPLAY environment variable.");
			exit(1);
		}

		if(wmClass != null && wmClass != "") {
			wmClass = wmClass.down();
		}
		else {
			stdout.printf("Error: wmClass is null or empty!");
			exit(1);
		}

		//Create gstreamer pipeline
		pipe = new Pipeline("pipe");
		bus = pipe.get_bus();

		//Set pulse source parameters
		pulsesrc = ElementFactory.make("pulsesrc", "source");
		pulsesrc.set("device", device);

		//Set encoding parameters
		lamemp3enc = ElementFactory.make("lamemp3enc", "encoder");
		lamemp3enc.set("bitrate", bitrate);
		lamemp3enc.set("target", 1);
		lamemp3enc.set("cbr", true);
		lamemp3enc.set("encoding-engine-quality", 2);

		//Create a queue so we can queue up encoded mp3 if the shout server lags
		queue = ElementFactory.make("queue", "lame-shout-queue");

		//Set shoutcast streaming parameters
		shout2send = ElementFactory.make("shout2send", "sink");
		shout2send.set("ip", ip);
		shout2send.set("port", port);
		shout2send.set("password", password);
		if(protocol == "icecast")
		{
			shout2send.set("mount", mount);
		}
		else
		{
			shout2send.set("protocol", 2);
		}

		//Add all the elements to the pipeline
		pipe.add_many(pulsesrc, lamemp3enc, queue, shout2send);

		//Link all the gstreamer elements together
		pulsesrc.link_many(lamemp3enc, queue, shout2send);

		//Ask Wnck for the latest tags and push them through the pipeline if they changed
		//4000 msec = 4 seconds is the frequency of this by default.
		Timeout.add(tagpoll, () => 
            {
				update_tags();
				return true;
			});

		//This one waits for the mainloop to start, then plays the pipeline.
		Timeout.add(2, () => 
            {
				stderr.printf("Setting pipeline state to PLAYING...\n");
				StateChangeReturn scr = pipe.set_state(Gst.State.PLAYING);
				string status = "UNKNOWN";
				switch(scr)
				{
					case StateChangeReturn.FAILURE:
						status = "FAILURE";
						break;
					case StateChangeReturn.SUCCESS:
						status = "SUCCESS";
						break;
					case StateChangeReturn.ASYNC:
						status = "ASYNC";
						break;
					case StateChangeReturn.NO_PREROLL:
						status = "NO_PREROLL";
						break;
				}
				stderr.printf("Pipeline state set result: %s\n", status);
				return false;
			});

		ml.run();
	}

	private void parse_opts(string[] args)
	{
		ctxt = new OptionContext(" - a program to send Spotify over Icecast2 using PulseAudio");
		ctxt.set_summary("The purpose of tribblify is to run while streaming Spotify using the Linux client to PulseAudio, and send the captured audio to Icecast2.");
		ctxt.set_description("Report all bugs to smcnam AT gmail DOT com");
		ctxt.set_help_enabled(true);
		ctxt.set_ignore_unknown_options(false);
		ctxt.add_main_entries(entries, null);
		try
		{
			if(!ctxt.parse(ref args))
			{
				printerr("Failed to parse command line arguments");
			}
		}
		catch(GLib.OptionError err)
		{
			stdout.printf("Failed to parse command line arguments\n");
			exit(1);
		}
	}

	private void update_tags()
	{
		bool changed = false;
		screen.force_update();
		unowned GLib.List<Wnck.Window> windows = screen.get_windows();
		string? artist = null;
		string? title = null;

		foreach(Wnck.Window window in windows) {
			//wmClass was already set to lowercase on startup
			if(window.get_class_group_name().down() == wmClass) {
				string? curr_window_name = window.get_name();
				stderr.printf("Found %s window; name=%s\n", wmClass, curr_window_name);
				string[] tokens = curr_window_name.split("-", 2);
				if(tokens.length == 2) {
					artist = tokens[0];
					title = tokens[1];
				}
				break;
			}
		}

		if(artist == null || artist == "") {
			artist = "Unknown Artist";
		}
		else {
			artist = artist.strip();
		}

		if(title == null || title == "") {
			title = "Unknown Title";
		}
		else {
			title = title.strip();
		}
		
		if(curr_artist == null || curr_artist != artist)
		{
			curr_artist = artist;
			changed = true;
		}

		if(curr_title == null || curr_title != title)
		{
			curr_title = title;
			changed = true;
		}

		stderr.printf("Changed: '%s'; Artist: '%s'; Title: '%s'\n", (changed ? "true" : "false"), curr_artist, curr_title);

		if(changed)
		{

			//These are pointers because we're doing manual memory management
			//The message and the event "own" their copies of the taglist
			//And the bus "owns" its copy of the message.
			TagList *list = new TagList.empty();
			list->add(TagMergeMode.REPLACE_ALL, Gst.Tags.ARTIST, artist, Gst.Tags.TITLE, title);
			Gst.Event *evt = new Gst.Event.tag(list);


			//I learned that the elements will probably ignore the bus message
			//But that they will pay attention to this event
			pipe.send_event(evt);
			list->unref();
			evt->unref();
		}
	}

	static int main (string[] args) 
	{
		string[] tmp = new string[0];
		unowned string[] arg = tmp;
		Gst.init(ref arg);
		Main app = new Main(args);

		return 0;
	}
}
