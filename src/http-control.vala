/* -*- Mode: C; indent-tabs-mode: t; c-basic-offset: 4; tab-width: 4 -*- */
/*
 * http-control.vala
 * Copyright (C) Sean McNamara 2018 <smcnam@gmail.com>
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
using Soup;
using Soup.Form;

public class TunableServer : Soup.Server 
{
	 public int tunablePort = 17536;
	 private PitchSetter? setter = null;

	 public TunableServer(PitchSetter? ps) {
		assert (this != null);
		this.setter = ps;
		this.add_handler (null, handler);
	 }

	 public void start() {
		try {
			this.listen_local(tunablePort, 0);
		} catch (Error e) {
			stdout.printf ("Error starting tunable server: %s\n", e.message);
		}
	 }

	 private static void handler(Soup.Server server, Soup.Message msg, string path, GLib.HashTable? query, Soup.ClientContext client) {
		unowned TunableServer self = server as TunableServer;
		Timeout.add(0, () => {
			URI uri = msg.get_uri();
			string _query = uri.get_query();

			//Parse the query and handle pitch
			HashTable<unowned string,unowned string> queryTable = Soup.Form.decode(_query);
			if(queryTable.contains("pitch")) {
				unowned string pitch = queryTable.get("pitch");
				double p = 0.0;
				if(double.try_parse(pitch, out p) && self.setter != null) {
					self.setter.set_pitch_value(p);
				}
			}
			
			// Resumes HTTP I/O on msg:
			self.unpause_message (msg);
			return false;
		});

		// Pauses HTTP I/O on msg:
		self.pause_message (msg);
	}
}
