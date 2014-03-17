
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
// valac --pkg gtk+-3.0 gcrc.vala -X -lm

public class ListBox : GLib.Object
{
    public enum WY_Columns
    {
        IDX,
            TYPE,
            LAT,
            LON,
            ALT,
            INT1,
            INT2,
            INT3,
            MARKER,
            ACTION,
            N_COLS
    }

    private Gtk.Menu menu;
    public Gtk.TreeView view;
    public Gtk.ListStore list_model;
    private MWPlanner mp;
    private bool purge;
    private Gtk.MenuItem shp_item;
    private ShapeDialog shapedialog;
    private DeltaDialog deltadialog;
    int lastid = 0;
    
    public ListBox()
    {
        purge=false;
    }
    
    public void import_mission(Mission ms)
    {
        Gtk.TreeIter iter;

        list_model.clear();
        lastid = 0;
        
        foreach (MissionItem m in ms.get_ways())
        {
            list_model.append (out iter);
            string no;
            switch (m.action)
            {
                case MSP.Action.RTH:
                case MSP.Action.LAND:
                case MSP.Action.SET_POI:
                case MSP.Action.SET_HEAD:
                    no="";
                    break;
                
                default:
                    lastid++;
                    no = lastid.to_string();
                    break;
            }
            
            list_model.set (iter,
                            WY_Columns.IDX, no,
                            WY_Columns.TYPE, MSP.get_wpname(m.action),
                            WY_Columns.LAT, m.lat,
                            WY_Columns.LON, m.lon,
                            WY_Columns.ALT, m.alt,
                            WY_Columns.INT1, m.param1,
                            WY_Columns.INT2, m.param2,
                            WY_Columns.INT3, m.param3,
                            WY_Columns.ACTION, m.action);
        }
        calc_mission();
    }

    public  MSP_WP[] to_wps()
    {
        Gtk.TreeIter iter;
        MSP_WP[] wps =  {};
        var n = 0;
        for(bool next=list_model.get_iter_first(out iter);next;next=list_model.iter_next(ref iter))
        {
            GLib.Value cell;
            list_model.get_value (iter, WY_Columns.ACTION, out cell);
            var typ = (MSP.Action)cell;
            if(typ != MSP.Action.UNASSIGNED)
            {
                var w = MSP_WP();
                n++;
                w.action = typ;
                list_model.get_value (iter, WY_Columns.IDX, out cell);
                w.wp_no = n;
                list_model.get_value (iter, WY_Columns.LAT, out cell);
                w.lat = (int32)Math.lround(((double)cell) * 10000000);
                list_model.get_value (iter, WY_Columns.LON, out cell);
                w.lon = (int32)Math.lround(((double)cell) * 10000000);
                list_model.get_value (iter, WY_Columns.ALT, out cell);
                w.altitude = (int32)(((int)cell) * 100);
                list_model.get_value (iter, WY_Columns.INT1, out cell);
                var tint = (int)cell;
                w.p1 = (uint16)tint;
                list_model.get_value (iter, WY_Columns.INT2, out cell);
                tint = (int)cell;
                w.p2 = (uint16)tint;
                list_model.get_value (iter, WY_Columns.INT3, out cell);
                tint = (int)cell;                
                w.p3 = (uint16)tint;
                w.flag = 0;
                wps += w;
            }
        }
        if(wps.length > 0)
            wps[wps.length-1].flag = 0xa5;
        return wps;
    }

    public bool validate_mission(MissionItem []wp, uint8 wp_flag)
    {
        int n_rows = list_model.iter_n_children(null);
        bool res = true;
        
        if(n_rows == wp.length)
        {
            int n = 0;
            var ms = to_mission();
            foreach(MissionItem  m in ms.get_ways())
            {
                if ((m.action != wp[n].action) ||
                    (Math.fabs(m.lat - wp[n].lat) > 1e-6) ||
                    (Math.fabs(m.lon - wp[n].lon) > 1e-6) ||
                    (m.alt != wp[n].alt) ||
                    (m.param1 != wp[n].param1) ||
                    (m.param2 != wp[n].param2) ||
                    (m.param3 != wp[n].param3))
                {
                    res = false;
                    break;
                }
                n++;
            }
        }
        else
        {
            res = false;
        }
        print("validate res = %s %d %d\n", res.to_string(), n_rows, wp.length);
        return res;
    }
    
    public Mission to_mission()
    {
        Gtk.TreeIter iter;
        int n = 0;
        MissionItem[] arry = {};
        var ms = new Mission();

        for(bool next=list_model.get_iter_first(out iter);next;next=list_model.iter_next(ref iter))
        {
            GLib.Value cell;
            list_model.get_value (iter, WY_Columns.ACTION, out cell);
            var typ = (MSP.Action)cell;
            if(typ != MSP.Action.UNASSIGNED)
            {
                var m = MissionItem();
                n++;
                m.action = typ;
                m.no = n;
                list_model.get_value (iter, WY_Columns.LAT, out cell);
                m.lat = (double)cell;
                list_model.get_value (iter, WY_Columns.LON, out cell);
                m.lon = (double)cell;
                list_model.get_value (iter, WY_Columns.ALT, out cell);
                m.alt = (int)cell;
                list_model.get_value (iter, WY_Columns.INT1, out cell);
                m.param1 = (int)cell;
                list_model.get_value (iter, WY_Columns.INT2, out cell);
                m.param2 = (int)cell;
                list_model.get_value (iter, WY_Columns.INT3, out cell);
                m.param3 = (int)cell;
                arry += m;
            }
        }
        ms.zoom = mp.view.get_zoom_level();
        ms.cy = mp.view.get_center_latitude();
        ms.cx = mp.view.get_center_longitude();
        ms.set_ways(arry);
        return ms;
    }

    public void create_view(MWPlanner _mp)
    {
        make_menu();

        mp = _mp;
        
        shapedialog = new ShapeDialog(mp.builder);
        deltadialog = new DeltaDialog(mp.builder);
        
            // Combo, Model:
        Gtk.ListStore combo_model = new Gtk.ListStore (1, typeof (string));
        Gtk.TreeIter iter;
        
        for(var n = MSP.Action.WAYPOINT; n <= MSP.Action.LAND; n += 1)
        {
            combo_model.append (out iter);
            combo_model.set (iter, 0, MSP.get_wpname(n));
        }
                
        list_model = new Gtk.ListStore (WY_Columns.N_COLS,
                                        typeof (string),
                                        typeof (string),
                                        typeof (double),
                                        typeof (double),
                                        typeof (int),
                                        typeof (int),
                                        typeof (int),
                                        typeof (int),
                                        typeof (Champlain.Label),
                                        typeof (MSP.Action)
                                        );

        view = new Gtk.TreeView.with_model (list_model);

        var sel = view.get_selection();
        sel.changed.connect(() => {
                update_selected_cols();
            });

        
        Gtk.CellRenderer cell = new Gtk.CellRendererText ();
        view.insert_column_with_attributes (-1, "ID", cell, "text", WY_Columns.IDX);
        
        Gtk.TreeViewColumn column = new Gtk.TreeViewColumn ();
        column.set_title ("Type");
        view.append_column (column);
                
        Gtk.CellRendererCombo combo = new Gtk.CellRendererCombo ();
        combo.set_property ("editable", true);
        combo.set_property ("model", combo_model);
        combo.set_property ("text-column", 0);
        column.pack_start (combo, false);
        column.add_attribute (combo, "text", 1);
        
        combo.changed.connect((path, iter_new) => {
                Gtk.TreeIter iter_val;
                Value val;
                combo_model.get_value (iter_new, 0, out val);
                var typ = (string)val;
                var action = MSP.lookup_name(typ);
                
                list_model.get_iter (out iter_val, new Gtk.TreePath.from_string (path));

                list_model.get_value (iter_val, WY_Columns.ACTION, out val);
                var old = (MSP.Action)val;
                if (old != action)
                {
                    list_model.set_value (iter_val, WY_Columns.ACTION, action);
                    list_model.set_value (iter_val, WY_Columns.TYPE, typ);
                    list_model.get_value (iter_val, WY_Columns.MARKER, out val);
                    var mk =  (Champlain.Label)val;
                    list_model.get_value (iter_val, WY_Columns.IDX, out val);
                    var no = (string)val;
                    mp.markers.change_label(mk, old, action, no);
                    switch (action)
                    {
                        case MSP.Action.JUMP:
                            list_model.set_value (iter_val, WY_Columns.LAT, 0.0);
                            list_model.set_value (iter_val, WY_Columns.LON, 0.0);
                            list_model.set_value (iter_val, WY_Columns.ALT, 0);
                            list_model.set_value (iter_val, WY_Columns.INT1, 0);
                            list_model.set_value (iter_val, WY_Columns.INT2, 0);
                            break;
                        case MSP.Action.POSHOLD_TIME:
                            Gtk.Entry ent = mp.builder.get_object ("entry2") as Gtk.Entry;
                            var ltime = int.parse(ent.get_text());
                            list_model.set_value (iter_val, WY_Columns.INT1, ltime);
                            break;
                        case MSP.Action.RTH:
                            list_model.set_value (iter_val, WY_Columns.LAT, 0.0);
                            list_model.set_value (iter_val, WY_Columns.LON, 0.0);
                            list_model.set_value (iter_val, WY_Columns.ALT, 0);
                            break;
                        case MSP.Action.LAND:
                            list_model.set_value (iter_val, WY_Columns.ALT, mp.conf.altitude);
                            break;
                        case MSP.Action.SET_HEAD:
                            list_model.set_value (iter_val, WY_Columns.LAT, 0.0);
                            list_model.set_value (iter_val, WY_Columns.LON, 0.0);
                            list_model.set_value (iter_val, WY_Columns.ALT, 0);
                            break;
                        default:
                            list_model.set_value (iter_val, WY_Columns.INT1, 0);
                            list_model.set_value (iter_val, WY_Columns.INT2, 0);
                            list_model.set_value (iter_val, WY_Columns.INT3, 0);
                            break;
                    }
                    renumber_steps(list_model);
                }
                
            });

        
        cell = new Gtk.CellRendererText ();
        view.insert_column_with_attributes (-1, "Lat.",
                                            cell,
                                            "text", WY_Columns.LAT);

        var col = view.get_column(WY_Columns.LAT);
        col.set_cell_data_func(cell, (col,_cell,model,iter) => {
                Value v;
                model.get_value(iter, WY_Columns.LAT, out v);
                double val = (double)v;
                string s = PosFormat.lat(val,mp.conf.dms);
                _cell.set_property("text",s);
            });

        cell.set_property ("editable", (mp.conf.dms == false));
        ((Gtk.CellRendererText)cell).edited.connect((path,new_text) => {
                list_validate(path,new_text,
                              WY_Columns.LAT,-90.0,90.0,false);
            });

        
        cell = new Gtk.CellRendererText ();
        view.insert_column_with_attributes (-1, "Lon.",
                                            cell, 
                                            "text", WY_Columns.LON);
        col = view.get_column(WY_Columns.LON);
        col.set_cell_data_func(cell, (col,_cell,model,iter) => {
                Value v;
                model.get_value(iter, WY_Columns.LON, out v);
                double val = (double)v;
                string s = PosFormat.lon(val,mp.conf.dms);
                _cell.set_property("text",s);
            });

        cell.set_property ("editable", (mp.conf.dms == false));

        ((Gtk.CellRendererText)cell).edited.connect((path,new_text) => {
                list_validate(path,new_text,
                              WY_Columns.LON,-180.0,180.0,false);
            });
        
        
        cell = new Gtk.CellRendererText ();
        cell.set_property ("editable", true);
        view.insert_column_with_attributes (-1, "Alt.",
                                            cell, 
                                            "text", WY_Columns.ALT);

        ((Gtk.CellRendererText)cell).edited.connect((path,new_text) => {
                list_validate(path,new_text,
                              WY_Columns.ALT,0.0,1000.0,true);
            });

        
        cell = new Gtk.CellRendererText ();
        cell.set_property ("editable", true);
        view.insert_column_with_attributes (-1, "P1",
                                            cell,
                                            "text", WY_Columns.INT1);
        ((Gtk.CellRendererText)cell).edited.connect((path,new_text) => {

                GLib.Value icell;
                Gtk.TreeIter iiter;
                list_model.get_iter (out iiter, new Gtk.TreePath.from_string (path));
                list_model.get_value (iiter, WY_Columns.ACTION, out icell);
                var typ = (MSP.Action)icell;
                if (typ == MSP.Action.JUMP)
                {
                     list_model.get_value (iiter, WY_Columns.IDX, out icell);
                     var iwp = (int)icell;
                     var nwp = int.parse(new_text);
                     if(nwp < 1 || nwp >= iwp)
                         return;
                }
                list_validate(path,new_text,
                              WY_Columns.INT1,0.0,65536.0,true);
            });

        
        cell = new Gtk.CellRendererText ();
        cell.set_property ("editable", true);
        view.insert_column_with_attributes (-1, "P2",
                                            cell,
                                            "text", WY_Columns.INT2);
        ((Gtk.CellRendererText)cell).edited.connect((path,new_text) => {
                list_validate(path,new_text,
                              WY_Columns.INT2,-1,65536.0,true);
            });
        
        
        cell = new Gtk.CellRendererText ();
        cell.set_property ("editable", true);
        view.insert_column_with_attributes (-1, "P3",
                                            cell,
                                            "text", WY_Columns.INT3);
        // Min val is -1 because only jump uses this.
        ((Gtk.CellRendererText)cell).edited.connect((path,new_text) => {
                list_validate(path,new_text,
                              WY_Columns.INT3,-1,65536.0,true);
            });
        
        view.set_headers_visible (true);
        view.set_reorderable(true);
        list_model.row_deleted.connect((path,iter) => {
                if (purge == false)
                {
                    renumber_steps(list_model);
                }
            });
        list_model.rows_reordered.connect((path,iter,rlist) => {
                renumber_steps(list_model);
            });
        
        view.button_press_event.connect( event => {
                if(event.button == 3)
                {
                    var time = event.time;
                    shp_item.sensitive=false;
                    int n_rows = list_model.iter_n_children(null);
                    if(n_rows == 1)
                    {
                        Gtk.TreeIter _iter;
                        Value val;
                        list_model.get_iter_first(out _iter);                    
                        list_model.get_value (_iter, WY_Columns.ACTION, out val);
                        if  ((MSP.Action)val == MSP.Action.SET_POI)
                        {
                            shp_item.sensitive=true;
                        }
                    }
                    menu.popup(null, null, null, 0, time);
                    return true;
                }
                return false;
            });

    }
    
    private void list_validate(string path, string new_text, int colno,
                               double minval, double maxval, bool as_int)
    {
        Gtk.TreeIter iter_val;
        var list_model = view.get_model() as Gtk.ListStore;
        
        list_model.get_iter (out iter_val, new Gtk.TreePath.from_string (path));
        double d;
        var res = double.try_parse(new_text, out d);
        if (res == true && (d <= maxval && d >= minval))
        {
            if (as_int == true)
            {
                var i = (int)Math.round(d);
                list_model.set_value (iter_val, colno, i);
            }
            else
            {
                list_model.set_value (iter_val, colno, d);
                mp.markers.add_list_store(this);
            }
            calc_mission();
        }
    }
    
    private void renumber_steps(Gtk.ListStore ls)
    {
        int n = 1;
        Gtk.TreeIter iter;
        for(bool next=ls.get_iter_first(out iter);next;next=ls.iter_next(ref iter))
        {
            GLib.Value cell;
            list_model.get_value (iter, WY_Columns.ACTION, out cell);
            switch ((MSP.Action)cell)
            {
                case MSP.Action.RTH:
                case MSP.Action.LAND:
                case MSP.Action.SET_POI:
                case MSP.Action.SET_HEAD:
                    ls.set_value (iter, WY_Columns.IDX, "");
                    break;
                
                default: 
                    ls.set_value (iter, WY_Columns.IDX, n);
                    n += 1;
                    break;
            }
        }
            /* rebuild the map */
        mp.markers.add_list_store(this);
        calc_mission();
    }


    private void update_selected_cols()
    {
        Gtk.TreeModel tm;
        Gtk.TreeIter iter;
        var treesel = view.get_selection ();        
        if (treesel != null)
        {
            treesel.get_selected (out tm, out  iter);
            Value val;
            list_model.get_value (iter, WY_Columns.ACTION, out val);
            MSP.Action act = (MSP.Action)val;
            string [] ctitles = {};
        
            switch (act)
            {
                case MSP.Action.WAYPOINT:
                case MSP.Action.POSHOLD_UNLIM:
                case MSP.Action.LAND:                
                    ctitles = {"Lat","Lon","Alt","","",""};
                    break;
                case MSP.Action.POSHOLD_TIME:
                    ctitles = {"Lat","Lon","Alt","Secs","",""};
                    break;
                case MSP.Action.RTH:
                    ctitles = {"","","Alt","Land","",""};
                    break;
                case MSP.Action.SET_POI:
                    ctitles = {"Lat","Lon","","","",""};
                    break;
                case MSP.Action.JUMP:
                    ctitles = {"","","","WP#","Rpt",""};
                    break;
                case MSP.Action.SET_HEAD:
                    ctitles = {"","","","Head","",""};
                    break;
            }
            var n = 2;
            foreach (string s in ctitles)
            {
                var col = view.get_column(n);        
                col.set_title(s);
                n++;
            }
        }
    }
    
    
    private void show_item(string s)
    {
        Gtk.TreeModel tm;
        Gtk.TreeIter iter;
        
        var treesel = view.get_selection ();        
        if (treesel != null)
        {
            Gtk.TreeIter step;
            treesel.get_selected (out tm, out  iter);
            switch(s)
            {
                case "Up":
                    step = iter;
                    tm.iter_previous(ref step);
                    list_model.move_before(ref iter, step);
                    break;
                case "Down":
                    step = iter;
                    tm.iter_next(ref step);
                    list_model.move_after(ref iter,step);
                    break;
                case "Delete":
                    list_model.remove(iter);
                    lastid--;
                    break;
                case "Insert":
                    insert_item(MSP.Action.UNASSIGNED,
                                mp.view.get_center_latitude(),
                                mp.view.get_center_longitude());
                    break;
                default:
                    stdout.printf("Not reached\n");
                    break;
            }
            calc_mission();
        }
    }

    public void insert_item(MSP.Action typ, double lat, double lon)
    {
        Gtk.TreeIter iter;
        Gtk.Entry ent = mp.builder.get_object ("entry1") as Gtk.Entry;
        var dalt = int.parse(ent.get_text());
        lastid++;
        list_model.append(out iter);
        list_model.set (iter,
                        WY_Columns.IDX, lastid.to_string(),
                        WY_Columns.TYPE, MSP.get_wpname(typ),
                        WY_Columns.LAT, lat,
                        WY_Columns.LON, lon,
                        WY_Columns.ALT, dalt,
                        WY_Columns.ACTION, typ );
        var is = list_model.iter_is_valid (iter);
        if (is == true)
            mp.markers.add_single_element(this,  iter, false);
        else
            mp.markers.add_list_store(this);
    }
    
    private void add_shapes()
    {
        ShapeDialog.ShapePoint[] pts;
        Gtk.TreeIter iter;
        Value val;
        double lat,lon;
        list_model.get_iter_first(out iter);                    
        list_model.get_value (iter, WY_Columns.LAT, out val);
        lat = (double)val;
        list_model.get_value (iter, WY_Columns.LON, out val);
        lon = (double)val;
        pts = shapedialog.get_points(lat,lon);
        foreach (ShapeDialog.ShapePoint p in pts)
        {
            insert_item(MSP.Action.WAYPOINT, p.lat, p.lon);
        }
        calc_mission();
    }

    private void do_deltas()
    {
        double dlat, dlon;
        int dalt;
        
        if(deltadialog.get_deltas(out dlat, out dlon, out dalt) == true)
        {
            if(dlat != 0.0 || dlon != 0.0 || dalt != 0)
            {
                Gtk.TreeIter iter;            
                for(bool next=list_model.get_iter_first(out iter); next;
                    next=list_model.iter_next(ref iter))
                {
                    GLib.Value cell;
                    list_model.get_value (iter, WY_Columns.TYPE, out cell);
                    var act = (MSP.Action)cell;
                    if (act == MSP.Action.RTH || act == MSP.Action.LAND || act == MSP.Action.SET_HEAD)
                        continue;

                    if(dlat != 0.0)
                    {
                        list_model.get_value (iter, WY_Columns.LAT, out cell);
                        var val = (double)cell;
                        val += dlat;
                        list_model.set_value (iter, WY_Columns.LAT, val);
                    }
                    
                    if(dlon != 0.0)
                    {
                        list_model.get_value (iter, WY_Columns.LON, out cell);
                        var val = (double)cell;
                        val += dlat;
                        list_model.set_value (iter, WY_Columns.LON, val);
                    }

                    if(dalt != 0)
                    {
                        list_model.get_value (iter, WY_Columns.ALT, out cell);
                        var val = (int)cell;
                        val += dalt;
                        list_model.set_value (iter, WY_Columns.ALT, val);
                    }

                }
                renumber_steps(list_model);
            }
        }
    }

    private void make_menu()
    {
        menu =   new Gtk.Menu ();
        Gtk.MenuItem item = new Gtk.MenuItem.with_label ("Move Up");
        item.activate.connect (() => {
                show_item("Up");
            });
        menu.add (item);
        item = new Gtk.MenuItem.with_label ("Move Down");
        item.activate.connect (() => {
                show_item("Down");
            });
        menu.add (item);
        
        item = new Gtk.MenuItem.with_label ("Delete");
        item.activate.connect (() => {
                show_item("Delete");
            });
        menu.add (item);

        item = new Gtk.MenuItem.with_label ("Insert");
        item.activate.connect (() => {
                show_item("Insert");
            });
        menu.add (item);

        item = new Gtk.MenuItem.with_label ("Set all altitudes");
        item.activate.connect (() => {
                set_alts(true);
            });
        menu.add (item);

        item = new Gtk.MenuItem.with_label ("Set zero value altitudes");
        item.activate.connect (() => {
                set_alts(false);
            });
        menu.add (item);

        shp_item = new Gtk.MenuItem.with_label ("Add shape");
        shp_item.activate.connect (() => {
                add_shapes();
            });
        menu.add (shp_item);
        shp_item.sensitive=false;

        item = new Gtk.MenuItem.with_label ("Delta updates");
        item.activate.connect (() => {
                do_deltas();
            });
        menu.add (item);
        
        item = new Gtk.MenuItem.with_label ("Clear Mission");
        item.activate.connect (() => {
                clear_mission();
            });
        menu.add (item);
        menu.show_all();
    }

    public void set_alts(bool flag)
    {
        Gtk.TreeIter iter;
        Gtk.Entry ent = mp.builder.get_object ("entry1") as Gtk.Entry;
        var dalt = int.parse(ent.get_text());

        for(bool next=list_model.get_iter_first(out iter); next;
            next=list_model.iter_next(ref iter))
        {
            GLib.Value cell;
            list_model.get_value (iter, WY_Columns.ACTION, out cell);
            var act = (MSP.Action)cell;
            if (act == MSP.Action.RTH || act == MSP.Action.LAND || act == MSP.Action.SET_HEAD)
                continue;
            if(flag == false)
            {
                list_model.get_value (iter, WY_Columns.ALT, out cell);
                if ((int)cell != 0)
                    continue;
            }
            list_model.set_value (iter, WY_Columns.ALT, dalt);
        }
    }
    
    public void set_selection(Gtk.TreeIter iter)
    {
        var treesel = view.get_selection ();        
        treesel.unselect_all();
        treesel.select_iter(iter);
    }
    
    public void clear_mission()
    {
                            
        lastid=0;
        mp.markers.remove_all();
        purge = true;
        list_model.clear();
        purge = false;
        calc_mission();
    }

    public void calc_mission()
    {
        string route;
        
        int n_rows = list_model.iter_n_children(null) + 1;
        if (n_rows > 0)
        {
            double d;
            int lt;
            var res = calc_mission_dist(out d, out lt);
            if (res == true)
            {
                var et = (int)(d / 2.5);
                 route = "Distance: %.0fm, fly: %ds, loiter: %ds".printf(d,et,lt);
            }
            else
                route = "Indeterminate distance";
        }
        else
        {
            route = "Empty mission";
        }
        mp.stslabel.set_text(route);
    }
    
    private bool calc_mission_dist(out double d, out int lt)
    {
        Gtk.TreeIter iter;
        MissionItem[] arry = {};
        for(bool next=list_model.get_iter_first(out iter);next;next=list_model.iter_next(ref iter))
        {
            GLib.Value cell;
            list_model.get_value (iter, WY_Columns.ACTION, out cell);
            var typ = (MSP.Action)cell;
            if (typ == MSP.Action.RTH)
                break;
            if(typ != MSP.Action.UNASSIGNED && typ != MSP.Action.SET_POI
               && typ != MSP.Action.SET_HEAD)
            {
                var m = MissionItem();
                m.action = typ;
                list_model.get_value (iter, WY_Columns.IDX, out cell);
                m.no = int.parse((string)cell);
                list_model.get_value (iter, WY_Columns.LAT, out cell);
                m.lat = (double)cell;
                list_model.get_value (iter, WY_Columns.LON, out cell);
                m.lon = (double)cell;
                list_model.get_value (iter, WY_Columns.ALT, out cell);
                m.alt = (int)cell;
                list_model.get_value (iter, WY_Columns.INT1, out cell);
                m.param1 = (int)cell;
                list_model.get_value (iter, WY_Columns.INT2, out cell);
                m.param2 = (int)cell;
                list_model.get_value (iter, WY_Columns.INT3, out cell);
                m.param3 = (int)cell;
                arry += m;
            }
            if (typ == MSP.Action.POSHOLD_UNLIM || typ == MSP.Action.LAND)
                break;
        }       
        var n = 0;
        var rpt = 0;
        double lx = 0.0,ly=0.0;
        bool ready = false;
        d = 0.0;
        lt = 0;
        
        var nsize = arry.length;

        if (nsize > 0)
        {
            do
            {
                var typ = arry[n].action;
                
                if(typ == MSP.Action.JUMP && arry[n].param2 == -1)
                {
                    d = 0.0;
                    lt = 0;
                    return false;
                }
                var cy = arry[n].lat;
                var cx = arry[n].lon;
                if (ready == true)
                {
                    double dx,cse;
                    if(typ == MSP.Action.JUMP)
                    {
                        var r = arry[n].param2;
                        rpt += 1;
                        if (rpt > r)
                            n += 1;
                        else
                            n = arry[n].param1-1;
                       continue;
                    }
                    Geo.csedist(ly,lx,cy,cx, out dx, out cse);
                    if (typ == MSP.Action.POSHOLD_TIME)
                    {
                        lt += arry[n].param1;
                    }
                    
                    d += dx;
                    if (typ == MSP.Action.POSHOLD_UNLIM)
                    {
                        break;
                    }
                    else
                    {
                        n += 1;
                    }
                }
                else
                {
                    ready = true;
                    n += 1;
                }
                lx = cx;
                ly = cy;
            } while (n < nsize);
        }
        d *= 1852.0;
        return true;
    }
}