
/*
 * Copyright (C) 2014 Jonathan Hudson <jh+mwptools@daria.co.uk>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

public struct PIDVals
{
    public double dmax;
    public double dfact;
    public bool hidden;
}

public struct PIDSet
{
    public int id;
    public unowned string? name;
    [CCode (array_length = false)]
    public PIDVals pids[3];
}


public class PIDEdit : Object
{
    private Gtk.Builder builder;
    private Gtk.Window window;
    private Gtk.Grid grid;
    private Gtk.SpinButton[] spins;
    private Gtk.Button conbutton;
    private Gtk.Label verslab;
    private MWSerial s;
    private string serdev;
    private uint8[] rawbuf;
    private bool is_connected;
    private string lastfile;
    private bool have_pids;
    private bool have_vers;
    private static const PIDSet[] ps =  {
        {0,"ROLL",{{20.00,0.100,false},{0.25,0.001,false},{100.00,1.000,false}}},
        {1,"PITCH",{{20.00,0.100,false},{0.25,0.001,false},{100.00,1.000,false}}},
        {2,"YAW",{{20.00,0.100,false},{0.25,0.001,false},{100.00,1.000,false}}},
        {3,"ALT",{{20.00,0.100,false},{0.25,0.001,false},{100.00,1.000,false}}},
        {4,"POS",{{5.00,0.010,false},{2.50,0.100,false},{100.00,1.000,true}}},
        {5,"POSR",{{25.00,0.100,false},{2.50,0.010,false},{0.25,0.001,false}}},
        {6,"NAVR",{{25.00,0.100,false},{2.50,0.010,false},{0.25,0.001,false}}},
        {7,"LEVEL",{{20.00,0.100,false},{0.25,0.001,false},{100.00,1.000,false}}},
        {8,"MAG",{{20.00,0.100,false},{0.25,0.001,true},{100.00,1.000,true}}}
    };

    private void save_file()
    {
	var chooser = new Gtk.FileChooserDialog (
            "Save PIDs", window,
            Gtk.FileChooserAction.SAVE,
            "_Cancel", Gtk.ResponseType.CANCEL,
            "_Save",  Gtk.ResponseType.ACCEPT);

        if(lastfile == null)
        {
            chooser.set_current_name("untitled-pids.json");
        }
        else
        {
            chooser.set_filename(lastfile);
        }

        if (chooser.run () == Gtk.ResponseType.ACCEPT)
        {
            lastfile = chooser.get_filename();
            save_data();
        }
        chooser.close ();
    }

    private void load_file()
    {
        var chooser = new Gtk.FileChooserDialog (
            "Load PID file", window, Gtk.FileChooserAction.OPEN,
            "_Cancel",
            Gtk.ResponseType.CANCEL,
            "_Open",
            Gtk.ResponseType.ACCEPT);

        Gtk.FileFilter filter = new Gtk.FileFilter ();
        filter.set_filter_name ("JSON PID files");
        filter.add_pattern ("*.json");
        chooser.add_filter (filter);
        filter = new Gtk.FileFilter ();
        filter.set_filter_name ("All Files");
        filter.add_pattern ("*");
        chooser.add_filter (filter);

        string fn = null;
        if (chooser.run () == Gtk.ResponseType.ACCEPT) {
            fn= chooser.get_filename();
        }
        chooser.close ();

        if(fn != null)
        {
            lastfile = fn;
            var idx = 0;
            rawbuf = new uint8[30];
            try
            {
                var parser = new Json.Parser ();
                parser.load_from_file (lastfile );
                var root_object = parser.get_root ().get_object ();
                foreach (var node in root_object.get_array_member ("pids").get_elements ())
                {
                    var item = node.get_object ();
                    rawbuf[idx++] = (uint8)item.get_int_member ("p");
                    rawbuf[idx++] = (uint8)item.get_int_member ("i");
                    rawbuf[idx++] = (uint8)item.get_int_member ("d");
                }
                set_pid_spins();
            } catch (Error e) {
                stderr.printf ("Failed to parse file\n");
            }
        }
    }

    private void save_data()
    {
         Json.Generator gen;
         gen = new Json.Generator ();
         Json.Builder builder = new Json.Builder ();
         builder.begin_object ();
         builder.set_member_name ("multiwii");
         builder.begin_object ();
         builder.set_member_name ("version");
         builder.add_string_value ("2.3");
         builder.end_object ();
         builder.set_member_name ("pids");
         builder.begin_array ();
         int idx = 0;
         for(var r = 0; r < 9; r++)
         {
             builder.begin_object ();
             builder.set_member_name ("id");
             builder.add_int_value (ps[r].id);
             builder.set_member_name ("name");
             builder.add_string_value (ps[r].name);
             builder.set_member_name ("p");
             builder.add_int_value (rawbuf[idx++]);
             builder.set_member_name ("i");
             builder.add_int_value (rawbuf[idx++]);
             builder.set_member_name ("d");
             builder.add_int_value (rawbuf[idx++]);
             builder.end_object ();
         }
         builder.end_array();
         builder.end_object ();
         Json.Node root = builder.get_root ();
         gen.set_pretty(true);
         gen.set_root (root);
         var json = gen.to_data(null);
         try{
             FileUtils.set_contents(lastfile,json);
         }catch(Error e){
             stderr.printf ("Error: %s\n", e.message);
         }
    }

    private void get_factors(int r, int c,
                            out double dmax, out double dmult,
                            out bool hideme)
    {
        dmax = ps[r].pids[c].dmax;
        dmult = ps[r].pids[c].dfact;
        hideme = ps[r].pids[c].hidden;
    }

    private void add_cmd(MSP.Cmds cmd, void* buf, size_t len, bool *flag)
    {
        Timeout.add(1000, () => {
                if (*flag == false)
                {
                    s.send_command(cmd,buf,len);
                    return true;
                }
                else
                {
                    return false;
                }
            });
        s.send_command(cmd,buf,len);
    }

    private void get_settings(out string[] devs)
    {
        devs={};
        Settings settings = null;
        var sname = "org.mwptools.pidedit";
        var uc = Environment.get_user_data_dir();
        uc += "/glib-2.0/schemas/";

        try
        {
            SettingsSchemaSource sss = new SettingsSchemaSource.from_directory (uc, null, false);
            var schema = sss.lookup (sname, false);
            if (schema != null)
                settings = new Settings.full (schema, null, null);
            else
                settings =  new Settings (sname);
        } catch {
            stderr.printf("No settings schema\n");
            Posix.exit(-1);
        }

        if (settings != null)
        {
            devs = settings.get_strv ("device-names");
        }
    }

    private void set_pid_spins()
    {
        int idx;
        uint8 *p = rawbuf;
        for(var r = 0; r< 10; r++)
        {
            idx = r*3;
            for (var c = 0; c < 3; c++)
            {
                double dmax,dmult;
                bool hideme;
                get_factors(r,c, out dmax, out dmult, out hideme);
                if(hideme == false)
                {
                    double v = (*p) * dmult;
                    if (r < 9)
                    {
                        spins[idx].set_value(v);
                    }
                }
                p++;
                idx++;
            }
        }
    }

    PIDEdit(string[] args)
    {
        lastfile = null;
        is_connected = false;
        have_pids = false;
        builder = new Gtk.Builder ();
        var fn = MWPUtils.find_conf_file("pidedit.ui");
        if (fn == null)
        {
            stderr.printf ("No UI definition file\n");
            Gtk.main_quit();
        }
        else
        {
            try
            {
                builder.add_from_file (fn);
            } catch (Error e) {
                stderr.printf ("Builder: %s\n", e.message);
                Gtk.main_quit();
            }
        }

        builder.connect_signals (null);
        window = builder.get_object ("window1") as Gtk.Window;
        foreach (var p in ps)
        {
            var s = "pidlabel_%02d".printf(p.id);
            var l =  builder.get_object (s) as Gtk.Label;
            l.set_text(p.name);
        }

        window.destroy.connect (Gtk.main_quit);
        s = new MWSerial();
        s.serial_event.connect((sd,cmd,raw,len,errs) => {
                if(errs == true)
                {
                    stderr.printf("Error on cmd %c (%d)\n", cmd,cmd);
                    return;
                }
                switch(cmd)
                {
                    case MSP.Cmds.IDENT:
                    have_vers = true;
                    have_pids = false;
                    var _mrtype = MSP.get_mrtype(raw[1]);
                    var vers="v%03d %s".printf(raw[0], _mrtype);
                    verslab.set_label(vers);
                    add_cmd(MSP.Cmds.PID,null,0, &have_pids);
                    break;

                    case MSP.Cmds.PID:
                    have_pids = true;
                    rawbuf = raw;
                    set_pid_spins();
                    break;
                }
            });

        try {
            string icon=null;
            icon = MWPUtils.find_conf_file("pidedit_icon.svg");
            window.set_icon_from_file(icon);
        } catch {};

        var dentry = builder.get_object ("comboboxtext1") as Gtk.ComboBoxText;
        conbutton = builder.get_object ("button4") as Gtk.Button;
        string[] devs;
        if(args.length > 1)
        {
            foreach(string a in args[1:args.length])
                dentry.append_text(a);
        }
        get_settings(out devs);
        foreach(string a in devs)
        {
            dentry.append_text(a);
        }

        var te = dentry.get_child() as Gtk.Entry;
        te.can_focus = true;
        dentry.active = 0;

        verslab = builder.get_object ("verslab") as Gtk.Label;
        verslab.set_label("");
        grid = builder.get_object ("grid1") as Gtk.Grid;
        var openbutton = builder.get_object ("button3") as Gtk.Button;
        var applybutton = builder.get_object ("button1") as Gtk.Button;
        var saveasbutton = builder.get_object ("button5") as Gtk.Button;

        openbutton.clicked.connect(() => {
                load_file();
            });

        saveasbutton.clicked.connect(() => {
                save_file();
            });

        applybutton.clicked.connect(() => {
                if(is_connected == true && have_pids == true)
                {
                    var n = 0;
                    foreach(Gtk.SpinButton b in spins)
                    {
                        var d = b.get_value();
                        var col = n % 3;
                        var row = n / 3;
                        double dmult,dmax;
                        bool hideme;

                        get_factors(row,col, out dmax, out dmult, out hideme);
                        if (hideme == false)
                        {
                            uint8 iv = (uint8)(d/dmult);
                            rawbuf[n] = iv;
                                }
                        n++;
                    }
                    Idle.add(() => {
                            s.send_command(MSP.Cmds.SET_PID,rawbuf,30);
                            s.send_command(MSP.Cmds.EEPROM_WRITE,null, 0);
                            s.send_command(MSP.Cmds.PID,null,0);
                            s.send_command(MSP.Cmds.PID,null,0);
                            return false;
                        });
                }
            });

//        openbutton.set_sensitive(false);
        applybutton.set_sensitive(false);
//        saveasbutton.set_sensitive(false);

        var closebutton = builder.get_object ("button2") as Gtk.Button;
        closebutton.clicked.connect(() => {
                Gtk.main_quit();
            });

        int idx;
        spins = new Gtk.SpinButton[27];

        for(int r = 0; r < 9; r++)
        {
            idx = r*3;
            for(int c = 0; c < 3; c++)
            {
                double dmult,dmax;
                bool hideme;
                get_factors(r,c, out dmax, out dmult, out hideme);
                var spin = new Gtk.SpinButton.with_range(0.0,dmax,dmult);
                spin.set_value(0.0);
                spins[idx] = spin;
                if(hideme == false)
                    grid.attach(spin,c+1,r+1,1,1);
                else
                    spin.hide();
                idx++;
            }
        }

        conbutton.clicked.connect(() => {
                if (is_connected == false)
                {
                    serdev = dentry.get_active_text();
                    if(s.open(serdev,115200) == true)
                    {
                        is_connected = true;
                        conbutton.set_label("Disconnect");
//                        openbutton.set_sensitive(true);
                        applybutton.set_sensitive(true);
//                        saveasbutton.set_sensitive(true);
                        add_cmd(MSP.Cmds.IDENT,null,0,&have_vers);
                    }
                    else
                    {
                        print("open failed\n");
                    }

                }
                else
                {
                    s.close();
                    conbutton.set_label("Connect");
//                    openbutton.set_sensitive(false);
                    applybutton.set_sensitive(false);
//                    saveasbutton.set_sensitive(false);
                    verslab.set_label("");
                    have_vers = false;
                    is_connected = false;
                    have_pids = false;
                }
            });

        window.show_all();
    }


    public void run()
    {
        Gtk.main();
    }


    public static int main (string[] args)
    {
        Gtk.init(ref args);
        PIDEdit app = new PIDEdit (args);
        app.run ();
        return 0;
    }
}