
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
//using Json;


public class Logger : GLib.Object
{
    public static bool is_logging { get; private set; }
    private static Json.Generator gen;
    private static OutputStream os;
    private static IOStream ios;

    public static void start()
    {
        time_t t;
        time_t(out t);
        var fn  = "mwp_%s.log".printf(Time.local(t).format("%F_%H%M%S"));
        File file = File.new_for_path (fn);
        try
        {
            ios = file.create_readwrite (FileCreateFlags.PRIVATE);
            os = ios.output_stream;
            is_logging = true;
        }
        catch
        {
            is_logging = false;
        }
        gen = new Json.Generator ();
    }

    public static void stop()
    {
        is_logging = false;
        try  { os.close(); } catch  {};
    }

    private static Json.Builder init(string typ)
    {
        time_t t;
        time_t(out t);
        Json.Builder builder = new Json.Builder ();
        builder.begin_object ();
	builder.set_member_name ("type");
        builder.add_string_value (typ);
	builder.set_member_name ("utime");
        builder.add_int_value (t);
        return builder;
    }

    public static void analog(MSP_ANALOG a)
    {
        var builder = init("analog");
        builder.set_member_name ("voltage");
        builder.add_double_value(((double)a.vbat)/10.0);
        builder.set_member_name ("power");
        builder.add_int_value(a.powermetersum);
        builder.set_member_name ("rssi");
        builder.add_int_value(a.rssi);
        builder.set_member_name ("amps");
        builder.add_int_value(a.amps);
        builder.end_object ();
        Json.Node root = builder.get_root ();
	gen.set_root (root);
        try  { gen.to_stream(os); } catch  {};
    }

    public static void comp_gps(int brg, uint16 range, uint8 update)
    {
	var builder = init ("comp_gps");
        builder.set_member_name ("bearing");
        builder.add_int_value(brg);
        builder.set_member_name ("range");
        builder.add_int_value(range);
        builder.set_member_name ("update");
        builder.add_int_value(update);
        builder.end_object ();
        Json.Node root = builder.get_root ();
	gen.set_root (root);
        try  { gen.to_stream(os); } catch  {};
    }

    public static void raw_gps(double lat, double lon, double cse, double spd,
                               int16 alt, uint8 fix, uint8 numsat)
    {
        var builder = init ("raw_gps");
        builder.set_member_name ("lat");
        builder.add_double_value(lat);
        builder.set_member_name ("lon");
        builder.add_double_value(lon);
        builder.set_member_name ("cse");
        builder.add_double_value(cse);
        builder.set_member_name ("spd");
        builder.add_double_value(spd);
        builder.set_member_name ("alt");
        builder.add_int_value(alt);
        builder.set_member_name ("fix");
        builder.add_int_value(fix);
        builder.set_member_name ("numsat");
        builder.add_int_value(numsat);
        builder.end_object ();
        Json.Node root = builder.get_root ();
	gen.set_root (root);
        try  { gen.to_stream(os); } catch  {};
     }

    public static void attitude(double dax, double day, int hdr)
    {
        var builder = init ("attitude");
        builder.set_member_name ("angx");
        builder.add_double_value(dax);
        builder.set_member_name ("angy");
        builder.add_double_value(day);
        builder.set_member_name ("heading");
        builder.add_int_value(hdr);
        builder.end_object ();
        Json.Node root = builder.get_root ();
	gen.set_root (root);
        try  { gen.to_stream(os); } catch  {};
    }

    public static void altitude(double estalt, double vario)
    {
        var builder = init ("altitude");
        builder.set_member_name ("estalt");
        builder.add_double_value(estalt);
        builder.set_member_name ("vario");
        builder.add_double_value(vario);
        builder.end_object ();
        Json.Node root = builder.get_root ();
	gen.set_root (root);
        try  { gen.to_stream(os); } catch  {};
    }

    public static void status(MSP_NAV_STATUS n)
    {
        var builder = init ("status");
        builder.set_member_name ("gps_mode");
        builder.add_int_value(n.gps_mode);
        builder.set_member_name ("nav_mode");
        builder.add_int_value(n.nav_mode);
        builder.set_member_name ("action");
        builder.add_int_value(n.action);
        builder.set_member_name ("wp_number");
        builder.add_int_value(n.wp_number);
        builder.set_member_name ("nav_error");
        builder.add_int_value(n.nav_error);
        builder.set_member_name ("target_bearing");
        builder.add_int_value(n.target_bearing);
        builder.end_object ();
        Json.Node root = builder.get_root ();
	gen.set_root (root);
        try  { gen.to_stream(os); } catch  {};
    }
}