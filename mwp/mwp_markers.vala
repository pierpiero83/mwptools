
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
using GLib;
using Clutter;

public class MWPMarkers : GLib.Object
{

    public  Champlain.PathLayer path;
    public Champlain.MarkerLayer markers;
    
    public MWPMarkers()
    {
        markers = new Champlain.MarkerLayer();        
        path = new Champlain.PathLayer();
    }


    private void get_text_for(MSP.Action typ, string no, out string text, out  Clutter.Color colour)
    {
        switch (typ)
        {
            case MSP.Action.WAYPOINT:
                text = @"WP $no";
                colour = { 0, 0xff, 0xff, 0xc8};
                break;
                
            case MSP.Action.POSHOLD_TIME:
                text = @"◷ $no"; // text = @"\u25f7 $no";
                colour = { 152, 70, 234, 0xc8};
                break;

            case MSP.Action.POSHOLD_UNLIM:
                text = @"∞ $no"; // text = @"\u221e $no";
                colour = { 0x4c, 0xfe, 0, 0xc8};
                break;

            case MSP.Action.RTH:
                text = @"⏏ $no"; // text = @"\u23cf $no";
                colour = { 0xff, 0x0, 0x0, 0xc8};
                break;

            case MSP.Action.LAND:                
                text = @"♜ $no"; // text = @"\u265c $no";
                colour = { 0xff, 0x9a, 0xf0, 0xc8};
                break;
                
            case MSP.Action.JUMP:
                text = @"⇒ $no"; // text = @"\u21d2 $no";
                colour = { 0xed, 0x51, 0xd7, 0xc8};
                break;

            case MSP.Action.SET_POI:
            case MSP.Action.SET_HEAD:
                 text = @"⌘ $no"; //text = @"\u2318 $no";
                colour = { 0xff, 0xfb, 0x2b, 0xc8};
                break;

            default:
                text = @"?? $no";
                colour = { 0xe0, 0xe0, 0xe0, 0xc8};
                break;
        }
    }
        
    public void add_single_element( ListBox l,  Gtk.TreeIter iter, bool rth)
    {
        Gtk.ListStore ls = l.list_model;
        Champlain.Label marker;
        GLib.Value cell;
        ls.get_value (iter, ListBox.WY_Columns.ACTION, out cell);
        var typ = (MSP.Action)cell;
        ls.get_value (iter, ListBox.WY_Columns.IDX, out cell);
        var no = (string)cell;
        string text;
        Clutter.Color colour;
        Clutter.Color black = { 0,0,0, 0xff };

        get_text_for(typ, no, out text, out colour);
        marker = new Champlain.Label.with_text (text,"Sans 10",null,null);
        marker.set_alignment (Pango.Alignment.RIGHT);
        marker.set_color (colour);
        marker.set_text_color(black);
        ls.get_value (iter, 2, out cell);
        var lat = (double)cell; 
        ls.get_value (iter, 3, out cell);
        var lon = (double)cell;
        
        marker.set_location (lat,lon);
        marker.set_draggable(true);
        markers.add_marker (marker);
        if (rth == false && typ != MSP.Action.SET_POI)
        {
            path.add_node(marker);
        }
        ls.set_value(iter,ListBox.WY_Columns.MARKER,marker);
        
        
        ((Champlain.Marker)marker).button_release.connect((e,u) => {
                    l.set_selection(iter);
            });
        
        ((Champlain.Marker)marker).drag_finish.connect(() => {
                GLib.Value val;
                ls.get_value (iter, ListBox.WY_Columns.ACTION, out val);
                if(val == MSP.Action.UNASSIGNED)
                {
                    string txt;
                    Clutter.Color col;
                    var act = MSP.Action.WAYPOINT;
                    ls.set_value (iter, ListBox.WY_Columns.TYPE, MSP.get_wpname(act));
                    ls.set_value (iter, ListBox.WY_Columns.ACTION, act);
                    get_text_for(act, no, out txt, out col);
                    marker.set_color (col);
                    marker.set_text(txt);
                }
                ls.set_value(iter, ListBox.WY_Columns.LAT, marker.get_latitude());
                ls.set_value(iter, ListBox.WY_Columns.LON, marker.get_longitude() );
                l.calc_mission();                
            } );
    }

    public void add_list_store(ListBox l)
    {
        Gtk.TreeIter iter;
        Gtk.ListStore ls = l.list_model;
        bool rth = false;
        
        remove_all();
        for(bool next=ls.get_iter_first(out iter);next;next=ls.iter_next(ref iter))
        {
            GLib.Value cell;
            ls.get_value (iter, ListBox.WY_Columns.ACTION, out cell);
            var typ = (MSP.Action)cell;
            switch (typ)
            {
                case MSP.Action.RTH:
                    rth = true;
                    ls.set_value(iter,ListBox.WY_Columns.MARKER, (Champlain.Label)null);
                    break;

                case MSP.Action.SET_HEAD:
                case MSP.Action.JUMP:
                    ls.set_value(iter,ListBox.WY_Columns.MARKER, (Champlain.Label)null);
                break;
                case MSP.Action.POSHOLD_UNLIM:
                case MSP.Action.LAND:
                    add_single_element(l,iter,rth);
                    rth = true;
                    break;
                    
                default:
                    add_single_element(l,iter,rth);
                    break;
            }
        }
    }

    public void change_label(Champlain.Label mk, MSP.Action old, MSP.Action typ, string no)
    {
        string text;
        Clutter.Color colour;
        get_text_for(typ, no, out text, out colour);
        mk.set_color (colour);
        mk.set_text(text);
            // FIXME if old type == SET_POI, then add node unless new RTH
            // FIXME if new type == RTH or SET_POI remove node from location
        if (old == MSP.Action.SET_POI && (typ != MSP.Action.RTH && typ != MSP.Action.SET_HEAD
                                          && typ != MSP.Action.JUMP))
        {
            path.add_node((Champlain.Marker)mk);
        }
        if (typ == MSP.Action.SET_POI || typ == MSP.Action.RTH || typ == MSP.Action.SET_HEAD
            || typ == MSP.Action.JUMP)
        {
            path.remove_node((Champlain.Marker)mk);
        }
    }
    
    public void remove_all()
    {
        markers.remove_all();
        path.remove_all();
    }
}
/*
                    Gtk.TreeIter _iter = get_iter_for_no(no);
                    var n = int.parse(no);
                    n = n - 1;
                    Gtk.TreeIter _iter;
                    Gtk.TreePath path = new Gtk.TreePath.from_string (n.to_string());
                    bool tmp = ls.get_iter (out _iter, path);
                    assert (tmp == true);
*/