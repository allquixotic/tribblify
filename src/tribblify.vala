/* -*- Mode: C; indent-tabs-mode: t; c-basic-offset: 4; tab-width: 4 -*- */
/*
 * main.c
 * Copyright (C) Sean McNamara 2012 <smcnam@gmail.com>
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
using Mpd;

extern void exit(int exit_code);

public class Main : GLib.Object 
{
	private MainLoop? ml = null;
	
	//For libmpdclient
	private Connection? cnxn = null;

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

	//mpd tunables
	private static int mpdport = 6600;
	private static string? mpdip = "localhost";
	private static string? mpdpass = null;
	private static int tagpoll = 4000;

	//For updating tags
	private string? curr_artist  = null;
	private string? curr_title   = null;
	//private bool    post_success = false;

	const OptionEntry[] entries =
	{
		{ "protocol",       'p',  0, OptionArg.STRING, ref protocol, "Protocol: shoutcast or icecast",   "proto_name"},
		{ "shout-ip",       's',  0, OptionArg.STRING, ref ip,       "Shoutcast/icecast IP/hostname",    "hostname"},
		{ "shout-port",     'o',  0, OptionArg.INT,    ref port,     "Shoutcast/icecast port",           "uint"},
		{ "shout-password", 'd',  0, OptionArg.STRING, ref password, "Shoutcast/icecast password",       "password"},
		{ "mount",          'm',  0, OptionArg.STRING, ref mount,    "Icecast mount point",              "mount"},
		{ "bitrate",        'b',  0, OptionArg.INT,    ref bitrate,  "MP3 CBR bitrate",                  "uint"},
		{ "device",         'i',  0, OptionArg.STRING, ref device,   "PulseAudio source",                "device"},
		{ "mpdip",          'z',  0, OptionArg.STRING, ref mpdip,    "mpd server hostname",              "hostname"},
		{ "mpdport",        'r',  0, OptionArg.INT,    ref mpdport,  "mpd port",                         "uint"},
		{ "mpd-password",   'w',  0, OptionArg.STRING, ref mpdpass,  "mpd password",                     "password"},
		{ "tagpoll",        't',  0, OptionArg.INT,    ref tagpoll,  "Frequency of tag polling in msec", "uint"},
		{null}
	};

	public Main(string[] args)
	{	
		ml = new MainLoop(null, false);
		
		parse_opts(args);

		//Create connection to mpd
		cnxn = new Connection(mpdip, mpdport, 60000);
		if(cnxn == null)
		{
			stdout.printf("Error: Connection to mpd couldn't be established!");
			exit(1);
		}

		if(mpdpass != null && mpdpass != "")
		{
			cnxn.run_password(mpdpass);
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

		//Ask mpd for the latest tags and push them through the pipeline if they changed
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
				string lala = "i dunno";
				switch(scr)
				{
					case StateChangeReturn.FAILURE:
						lala = "FAILURE";
						break;
					case StateChangeReturn.SUCCESS:
						lala = "SUCCESS";
						break;
					case StateChangeReturn.ASYNC:
						lala = "ASYNC";
						break;
					case StateChangeReturn.NO_PREROLL:
						lala = "NO_PREROLL";
						break;
				}
				stderr.printf("Pipeline state set result: %s\n", lala);
				return false;
			});

		//This will post the pipeline state to stderr every 10 seconds.
		/*
		Timeout.add(10000, () =>
		            {
						Gst.State st;
						Gst.State pend;
						StateChangeReturn scr = pipe.get_state(out st, out pend, Gst.CLOCK_TIME_NONE);
						string lala = "i dunno";
						string sst = "i dunno";
						string spend = "i dunno";
						switch(scr)
						{
							case StateChangeReturn.FAILURE:
								lala = "FAILURE";
								break;
							case StateChangeReturn.SUCCESS:
								lala = "SUCCESS";
								break;
							case StateChangeReturn.ASYNC:
								lala = "ASYNC";
								break;
							case StateChangeReturn.NO_PREROLL:
								lala = "NO_PREROLL";
								break;
						}

						switch(st)
						{
							case Gst.State.VOID_PENDING:
								sst = "VOID_PENDING";
								break;
							case Gst.State.NULL:
								sst = "NULL";
								break;
							case Gst.State.READY:
								sst = "READY";
								break;
							case Gst.State.PAUSED:
								sst = "PAUSED";
								break;
							case Gst.State.PLAYING:
								sst = "PLAYING";
								break;
						}

						switch(pend)
						{
							case Gst.State.VOID_PENDING:
								spend = "VOID_PENDING";
								break;
							case Gst.State.NULL:
								spend = "NULL";
								break;
							case Gst.State.READY:
								spend = "READY";
								break;
							case Gst.State.PAUSED:
								spend = "PAUSED";
								break;
							case Gst.State.PLAYING:
								spend = "PLAYING";
								break;
						}
						
						stderr.printf("Pipeline get_state results:\n\tCurrent: %s\n\tPending: %s\n\tReturn result:%s\n", 
						              sst, spend, lala);

						return true;
					});*/

		ml.run();
	}

	private void parse_opts(string[] args)
	{
		ctxt = new OptionContext(" - a stupid program");
		ctxt.set_summary("Placeholder for program summary");
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

		stderr.printf("Options parsed:\n" +
		              "protocol: %s\n" +
		              "ip: %s\n" +
		              "port: %d\n" +
		              "password: %s\n" +
		              "mount: %s\n" +
		              "bitrate: %d\n" +
		              "device: %s\n" +
		              "mpdip: %s\n" +
		              "mpdport: %d\n", 
		              protocol,
		              ip,
		              port,
		              password,
		              mount,
		              bitrate,
		              device,
		              mpdip,
		              mpdport);
	}

	private void update_tags()
	{
		bool changed = false;
		int songid;
		Status? sta = cnxn.run_status();
		if(sta != null)
		{
			songid = sta.song_id;
			Song song = cnxn.run_get_queue_song_id(songid);
			string artist = song.get_tag(TagType.ARTIST, 0);
			string title = song.get_tag(TagType.TITLE, 0);
			if(curr_artist == null || curr_artist != artist)
			{
				curr_artist = (artist != null ? artist : "");
				changed = true;
			}

			if(curr_title == null || curr_title != title)
			{
				curr_title = (title != null ? title : "");
				changed = true;
			}

			if(changed)
			{
				stderr.printf("Artist: %s\nTitle: %s\n", artist, title);

				//These are pointers because we're doing manual memory management
				//The message and the event "own" their copies of the taglist
				//And the bus "owns" its copy of the message.
				TagList *list = new TagList();
				list->add(TagMergeMode.REPLACE_ALL, Gst.TAG_ARTIST, artist, Gst.TAG_TITLE, title);
				Gst.Event *evt = new Gst.Event.tag(list->copy());

				//Commenting this for now, since the bus message does nothing.
				/*Gst.Message *msg = new Gst.Message.tag(pulsesrc, list);
				if(bus.post(msg))
				{
					post_success = true;
					//stderr.printf("Posted bus message for new tags\n");
				}
				else
				{
					post_success = false;
					stderr.printf("Failed to post bus message\n");
				}*/

				//I learned that the elements will probably ignore the bus message
				//But that they will pay attention to this event
				//So I'm sending an event, which is the REAL action here, not the message above.
				pipe.send_event(evt);
			}
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
