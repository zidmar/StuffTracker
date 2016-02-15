
define([
    "dojo/request/xhr",
    "dojo/io-query",
    "dojo/dom",
    "dojo/dom-style",
    "dijit/registry",
    "dojo/dom-construct",
    "dojo/on",
    "dojo/dom-attr",
    "dojo/keys",
    "dojo/dom-form",
    "dojo/_base/declare",
    "dijit/_WidgetBase",
    "dijit/popup",
    "dojo/when",
    "dojo/_base/lang",
    
    "dojo/store/Cache",
    "dojo/store/Memory",
    "dojo/store/JsonRest",
    "gridx/core/model/cache/Async",
    "gridx/Grid",
    
    "dijit/layout/TabContainer",
    "dijit/layout/BorderContainer",
    "dijit/layout/ContentPane",
    
    "dijit/form/Button",
    "dijit/form/TextBox",
    "dijit/form/NumberTextBox",
    "dijit/form/FilteringSelect",
    "dijit/form/DateTextBox",
    "dijit/form/Textarea",
    "dijit/form/CheckBox",
    "dijit/form/DropDownButton",
    "dijit/form/ValidationTextBox",
    "dijit/form/NumberSpinner",

    "dijit/Dialog",
    "dijit/TooltipDialog",
    "dijit/ProgressBar",

    "arc/common",

    "gridx/modules/Filter",

    "gridx/modules/Header",
    "gridx/modules/Bar",
    "gridx/support/Summary",
    "gridx/modules/VirtualVScroller",
    "gridx/modules/CellWidget",
    "gridx/modules/extendedSelect/Row",
    "gridx/modules/IndirectSelectColumn",
    "gridx/modules/Edit",
    "gridx/core/model/extensions/Modify",
    "gridx/modules/ColumnLock",
    "gridx/modules/ColumnResizer",
    "gridx/modules/SingleSort",
    "gridx/modules/Pagination",
    "gridx/modules/pagination/PaginationBar",

    "dojo/domReady!"
    
], function(xhr, ioQuery, dom, domStyle, registry, domConstruct, on, domAttr, keys, domForm, declare, _WidgetBase, popup, when, lang, dojoCache, Memory, JsonRest, Cache, Grid, TabContainer, BorderContainer, ContentPane, Button, TextBox, NumberTextBox, FilteringSelect, DateTextBox, Textarea, CheckBox, DropDownButton, ValidationTextBox, NumberSpinner, Dialog, TooltipDialog, ProgressBar, common, Filter ){

    var arc = {};

    ////
    // Selection
    ////

    var main_uri      = domAttr.get(dom.byId("main_uri"),"value");
    var static_uri    = domAttr.get(dom.byId("static_uri"),"value");
    var session_user  = domAttr.get(dom.byId("session_user"),"value");
    var session_admin = domAttr.get(dom.byId("session_admin"),"value");
    var program_title = domAttr.get(dom.byId("program_title"),"value");

    ////
    // Stores
    ////

    // Memory - for cache
    
    var cache_store_data = [{}];
    var cache_store = new Memory({data: cache_store_data});
    
    // JsonRest

    var stuff_tracker_store   = JsonRest({target:main_uri+"/stuff_tracker/"});
    var memory_store_98       = new Memory();
    stuff_tracker_store_cache = new dojoCache(stuff_tracker_store,memory_store_98);   

    var column_store          = JsonRest({target:main_uri+"/column_grid/"});

    var column_type_store_select   = JsonRest({target:main_uri+"/filtering_select/column_type/"});
    var memory_store_99            = new Memory();
    column_type_store_select_cache = new dojoCache(column_type_store_select,memory_store_99);   

    ////
    // Layout
    ////

    arc.site_layout = new function(){

        var header_logo  = static_uri+"images/color_swatch.png";
        var header_title = program_title;

        var header_home_link = {
            id:"header_home",
            innerHTML:"Home",
            "class":"headerLink",
            style:{cursor:"pointer",padding:"0 6px 0 6px",borderLeft:"1px dotted silver"},
            click: function(evt){
                setTimeout(window.location = main_uri+'/',3000);
            }
        };

        var header_add_link = {
            id:"header_add",
            innerHTML:"Add Entry",
            "class":"headerLink",
            style:{cursor:"pointer",padding:"0 6px 0 6px"},
            click: function(evt){

                if(!registry.byId('dialog_add_progress')){

                    createAddDialog(); 
                    clearAddForm();

                    registry.byId('dialog_add').show();
                }
                else{

                    clearAddForm();
                    registry.byId('dialog_add').show();
                }
            }
        };

        var header_refresh_link = {
            id:"header_refresh",
            innerHTML:"Refresh",
            "class":"headerLink",
            style:{cursor:"pointer",padding:"0 6px 0 6px",borderLeft:"1px dotted silver"},
            click: function(evt){
                cache_store.remove("filter");
                setGridFilter('gridx_Grid_0',{});
            }
        };

        var header_export_link = {
            id:"header_export",
            innerHTML:"Export",
            "class":"headerLink",
            style:{cursor:"pointer",padding:"0 6px 0 6px",borderLeft:"1px dotted silver"},
            click: function(evt){

                var query = {};

                var grid_cache = cache_store.get("filter") || {};
                delete grid_cache['id'];
                for (var attrname in grid_cache) { query[attrname] = grid_cache[attrname]; }

                var uri = main_uri+'/stuff_tracker/';
                var query_to_string = ioQuery.objectToQuery(query);
                if(query_to_string){
                    uri = uri + '?' + query_to_string + '&output=1';
                }
                else{
                    uri = uri + '?output=1';
                }
                window.open(uri);
            }
        };

        var header_admin_link = {
            id:"header_admin",
            innerHTML:"Settings",
            "class":"headerLink",
            style:{cursor:"pointer",padding:"0 6px 0 0",borderRight:"1px dotted silver"},
            click: function(evt){

                if(!registry.byId('dialog_admin_add_textbox_0')){
                    if(session_admin == 1){
                        createAdminDialog(); 
                        registry.byId('dialog_admin').show();
                    }
                }
                else{
                    if(session_admin == 1){
                        registry.byId('dialog_admin').show();
                    }
                }
            }
        };

        var header_filter_link = {
            id:"header_filter",
            innerHTML:"Advanced Filter",
            "class":"headerLink",
            style:{cursor:"pointer",padding:"0 6px 0 6px",marginRight:"5px"},
            click: function(evt){

                // Show Dialog
                createFilterDialog(); 
                registry.byId('dialog_filter').show();
            }
        };

        var header_search_textbox = new TextBox({
            id: "header_search_textbox",
            name: "header_search_textbox",
            value: "",
            placeHolder: "Search Entries",
            style:"width:220px;",
            intermediateChanges: true
        });

        var header_search_button  = new Button({
            id: "header_search_button",
            label: '<img style="width:14px;height:14px" src="'+static_uri+'images/find.png" title="Search for Services">',
            "class": "tooltipLink"
        });

        registry.byId("header_search_textbox").lastValue = '';
        var filter_textbox_timeout;

        on(registry.byId("header_search_textbox"), "change", function(evt){

            var value = this.get("value");
            var key   = evt.keyCode;

            if(value != this.lastValue) {

                this.lastValue = value;

                if(filter_textbox_timeout) { clearTimeout(filter_textbox_timeout); }
                
                filter_textbox_timeout = setTimeout(function() {

                    if(value == ''){
                        setGridFilter('gridx_Grid_0',{});
                        cache_store.remove("filter");
                        registry.byId("header_search_button").set("label",'<img style="width:14px;height:14px" src="'+static_uri+'images/find.png" title="Filter the Service table">');
                    }
                    else{
                        registry.byId('gridx_Grid_0').filter.setFilter(
                            Filter.contain(
                                Filter.column('search'), 
                                Filter.value(value)
                            )
                        );
                        cache_store.put({ id:"filter", query: value });

                        registry.byId("header_search_button").set("label",'<img style="width:14px;height:14px" src="'+static_uri+'images/delete.png" title="Clear the Service table filter">');
                        on(registry.byId("header_search_button"), "click", function(){
                            registry.byId("header_search_button").set("label",'<img style="width:14px;height:14px" src="'+static_uri+'images/find.png" title="Filter the Service table">');
                            registry.byId("header_search_textbox").set("value",null);
                        });
                    }
                }, key == keys.ENTER ? 0 : 700);
            }
        });

        var header_logout_link = {
            id:"header_logout_link",
            innerHTML:"Logout",
            "class":"headerLink",
            style:{ cursor: "pointer",marginRight:"5px" },
            click: function(evt){
                window.location = main_uri+"/logout";
            }
        };

        var border_container = new BorderContainer({id: "outside_container",gutters:false,style:"padding: 0"});

        // Top Pane
        var top_pane = new ContentPane({region:"top",style:"background-color: #e8edfe;height:32px;padding:0;border:0;"}).placeAt(border_container);

        var tp = new Object();

        tp["0"]  = domConstruct.create('table', {border:"0",style:{width:"100%",whiteSpace:"nowrap"}},top_pane.containerNode);
        tp["1"]  = domConstruct.create('tbody', {},tp["0"]);
        tp["2"]  = domConstruct.create('tr', {},tp["1"]);
        tp["3"]  = domConstruct.create('td', {style:{width:"20px",height:"5px",paddingRight:"2px",paddingLeft:"2px"}},tp["2"]);
        tp["4"]  = domConstruct.create('img', {src:header_logo,alt:"Active",style:{verticalAlign:"middle"}},tp["3"]);
        tp["5"]  = domConstruct.create('td', {style:{width:"100px",fontSize:"14px",fontWeight:"bold",verticalAlign:"middle"}},tp["2"]);
        tp["6"]  = domConstruct.create('span', {style:{paddingLeft:"6px",borderLeft:"1px dotted silver"},innerHTML:header_title},tp["5"]);
        tp["7"]  = domConstruct.create('td', {style:{width:"200px",verticalAlign:"middle"}},tp["2"]);
        tp["8"]  = domConstruct.create('span',header_home_link,tp["7"]);
        tp["9"]  = domConstruct.create('span',header_refresh_link,tp["7"]);
        tp["10"] = domConstruct.create('span',header_export_link,tp["7"]);

        tp["11"] = domConstruct.create('td', {style:{width:"200px",textAlign:"center",verticalAlign:"middle"}},tp["2"]);
        tp["12"] = domConstruct.create('span',header_add_link,tp["11"]);

        tp["13"] = domConstruct.create('td', {style:{textAlign:"right",verticalAlign:"middle"}},tp["2"]);
        if(session_admin == 1){
            tp["14"] = domConstruct.create('span',header_admin_link,tp["13"]);
        }
        tp["15"] = domConstruct.create('span',header_filter_link,tp["13"]);
        header_search_textbox.placeAt(tp["13"]);
        tp["16"] = domConstruct.create('span', {innerHTML:"&nbsp;&nbsp;"},tp["13"]);
        header_search_button.placeAt(tp["13"]);
        tp["17"] = domConstruct.create('span', {style:{marginLeft:"8px",padding:"0 0 0 8px",borderLeft:"1px dotted silver"},innerHTML:"Hello: <strong>"+session_user+"</strong>&nbsp;&bull;&nbsp;"},tp["13"]);
        tp["18"] = domConstruct.create('span', header_logout_link,tp["13"]);

        // Center Pane
        var center_pane = new ContentPane({id:"main_container",region:"center",splitter:false,style:"padding:5px;border:1px solid silver;"}).placeAt(border_container);

        return border_container;
    }

    arc.site_layout.placeAt(document.body);
    arc.site_layout.startup();

    var fetchColumns = xhr.get(main_uri+"/fetch_columns", {
        handleAs: "json",
        timeout: 5000,
        preventCache: false
    })

    createServiceTab({store:stuff_tracker_store_cache,query:{}});

    new Dialog({ id:'dialog_add',    title: "New Entry" });
    new Dialog({ id:'dialog_admin',  title: "Settings" });
    new Dialog({ id:'dialog_filter', title: "Advanced Filter" });

    function createDialog(fn_object){
        var myDialog = new Dialog({
            id:fn_object.rid,
            title: fn_object.title
        });
        return myDialog;
    }

    ///////////////////////////////////////////////////////////////////////////
    
    ////
    // Dialogs
    ////
   
    function createAddDialog(){

        fetchColumns.then(function(res){

            for (var i in res){

                var id    = "dialog_add_form_object_"+i;
                var type  = res[i].type;
                var nameC = res[i].description;

                if(!registry.byId('dialog_add_form_object_'+i)){

                    if(type == "varchar"){
                        new TextBox({ id: id, name: id, placeHolder: "Add "+nameC });
                    }
                    if(type == "integer"){
                        if(res[i].protected != 1){
                            new NumberSpinner({ id: id, name: id, placeHolder: "Add "+nameC, constraints: {min:1, places:0} });
                        }
                    }
                    if(type == "select"){

                        var url  = main_uri+"/filtering_select/"+res[i].id+"/";

                        new FilteringSelect({ 
                            id: id, 
                            name: id, 
                            value: "", 
                            required: false, 
                            placeHolder: "Select "+nameC,
                            store: JsonRest({target:url})
                        });
                    }
                    if(type == "date"){
                        new DateTextBox({ id: id, name: id, placeHolder: "Add "+nameC });
                    }
                }
            }

            // Submit 
            var dialog_add_button1 = new Button({
                label: "Submit",
                onClick: function(){
                    
                    domStyle.set(registry.byId("dialog_add_progress").domNode, "display", "block");
                    registry.byId("dialog_add_progress").set({indeterminate: true, maximum: 100, label: 'Loading...'});
                    
                    // Create a form to handle Grid Data
                    var form = document.createElement("form");
                    form.setAttribute("id", "form_name");
                    form.setAttribute("name", "form_name");
                    dojo.body().appendChild(form);
                        
                    var element_object = new Object();

                    for (var i in res){
                        if(res[i].protected != 1){
                            var id    = "dialog_add_form_object_"+i;
                            var name  = res[i].name;
                            var type  = res[i].type;
                            var value = registry.byId(id).get("value");

                            if(type == "date"){
                                if(registry.byId(id).get("value")){
                                    value = common.format_date(registry.byId(id).get("value"));
                                }
                            } 

                            element_object[i] = document.createElement("input");
                            element_object[i].setAttribute("type", "hidden");
                            element_object[i].setAttribute("name", name);
                            element_object[i].setAttribute("value", value );
                            form.appendChild(element_object[i]);
                        }
                    }
                    
                    xhr.post(main_uri+"/add", {
                        data: domForm.toObject("form_name"),
                        handleAs: "text"
                    }).then(function(response){
                        
                        setGridFilter('gridx_Grid_0',{});
                        cache_store.remove("filter");

                        // Remove Form
                        dojo.body().removeChild(form);

                        var match_error = response.match(/^Error/g);

                        if(!match_error){
                            setTimeout(function(){
                                registry.byId('dialog_add').hide();
                            },2000);
                        }
                        
                        //Stop ProgressBar
                        registry.byId("dialog_add_progress").set({indeterminate: false, label: response, value: 100});
                    }, function(error){
                        console.log("An error occurred: " + error);
                        return error;
                    });
                }
            });

            var dialog_add_button2 = new Button({
                label: "Clear",
                onClick: function(){
                    clearAddForm();
                }
            });

            var dialog_add_progress = new ProgressBar({
                id: "dialog_add_progress",
                style:"width:100%;", 
                value: ""
            });

            ////
            // Display
            ////

            var content_pane = new ContentPane();

            var cp_object = new Object();

            cp_object["0"] = domConstruct.create('table', {border:"0",style:{width:"400px"}},content_pane.containerNode);
            cp_object["1"] = domConstruct.create('tbody', {},cp_object["0"]);
            cp_object["2"] = domConstruct.create('tr', {},cp_object["1"]);
            cp_object["3"] = domConstruct.create('td', {colSpan:'2',style:{textAlign:"center",paddingBottom:"15px"}},cp_object["2"]);
            domConstruct.create('span', {innerHTML:"Complete the following to create a new entry"},cp_object["3"]);

            var required_object = new Object();

            for (var i in res){

                  if(res[i].protected != 1){

                    var nameC = res[i].description;

                    required_object[i] = domConstruct.create('tr', {},cp_object["1"]);
                    required_object[i+"a"] =domConstruct.create('td', {style:{textAlign:"right",padding:"5px",width:"40%"}},required_object[i]);
                    domConstruct.create('span', {innerHTML:nameC+":"},required_object[i+"a"]);
                    required_object[i+"b"] = domConstruct.create('td', {style:{textAlign:"left",paddingLeft:"10px",width:"60%"}},required_object[i]);
                    registry.byId("dialog_add_form_object_"+i).placeAt(required_object[i+"b"]);
                }
            }

            cp_object["4"] = domConstruct.create('tr', {},cp_object["1"]);
            cp_object["5"] = domConstruct.create('td', {colSpan:'2',style:{padding:"10px 0 5px 0",textAlign:"center"}},cp_object["4"]);
            dialog_add_button1.placeAt(cp_object["5"]);
            dialog_add_button2.placeAt(cp_object["5"]);
            cp_object["6"] = domConstruct.create('tr', {},cp_object["1"]);
            cp_object["7"] = domConstruct.create('td', {colSpan:'2',style:{textAlign:"center"}},cp_object["6"]);
            dialog_add_progress.placeAt(cp_object["7"]);

            registry.byId("dialog_add").set("content",content_pane);
        });
    }

    function clearAddForm(){

        fetchColumns.then(function(res){

            registry.byId("dialog_add_progress").set({indeterminate: false, maximum: 100, label: "",value: ""});
            domStyle.set(registry.byId("dialog_add_progress").domNode, "display", "none");

            for (var i in res){

                var id   = "dialog_add_form_object_"+i;
                var type = res[i].type;

                if( (type == "varchar") || (type == "integer") || (type == "date") ){
                    if(res[i].protected != 1){
                        registry.byId(id).set("value",null);
                    }
                }
                if(type == "select"){
                    registry.byId(id).set("displayedValue",null);
                }
            }
            registry.byId('dialog_add').show();
        });
    }

    function createModifyDialog(fn_object){

        fetchColumns.then(function(res){

            for (var i in res){

                var id    = "dialog_modify_form_object_"+fn_object.rid+"_"+i;
                var type  = res[i].type;
                var nameC = res[i].description;

                if(type == "varchar"){
                    new TextBox({ id: id, name: id, placeHolder: "Add "+nameC });
                }
                if(type == "integer"){
                    if(res[i].protected != 1){
                        new NumberSpinner({ id: id, name: id, placeHolder: "Add "+nameC, constraints: {min:1, places:0} });
                    }
                }
                if(type == "select"){

                    var url  = main_uri+"/filtering_select/"+res[i].id+"/";

                    new FilteringSelect({ 
                        id: id, 
                        name: id, 
                        value: "", 
                        required: false, 
                        placeHolder: "Select "+nameC,
                        store: JsonRest({target:url})
                    });
                }
                if(type == "date"){
                    new DateTextBox({ id: id, name: id, placeHolder: "Add "+nameC });
                }
            }

            var dialog_modify_button = new Button({
                id: "dialog_modify_button_"+fn_object.rid,
                label: "Update",
                onClick: function(){
                    
                    domStyle.set(registry.byId("dialog_modify_progress_"+fn_object.rid).domNode, "display", "block");
                    registry.byId("dialog_modify_progress_"+fn_object.rid).set({indeterminate: true, maximum: 100, label: 'Loading...'});

                    var current_grid = registry.byId('gridx_Grid_0');

                    for (var i in res){

                        if(res[i].protected != 1){

                            var id   = "dialog_modify_form_object_"+fn_object.rid+"_"+i;
                            var type = res[i].type;

                            var form_object_text = new Object();
                            form_object_text[ res[i].name ] = registry.byId(id).get("value");

                            var form_object_select = new Object();
                            form_object_select[ res[i].name+"_id" ] = registry.byId(id).get("value");
                            form_object_select[ res[i].name ]       = registry.byId(id).get("displayedValue");

                            if(type == "varchar"){
                                if(registry.byId(id).get("value")){
                                    current_grid.model.set(fn_object.rid,form_object_text);
                                }
                            }
                            if(type == "date"){
                                if(registry.byId(id).get("value")){
                                    var form_object_date = new Object();
                                    form_object_date[ res[i].name ] = common.format_date(registry.byId(id).get("value"));
                                    current_grid.model.set(fn_object.rid,form_object_date);
                                }
                            }
                            if(type == "select"){
                                if(registry.byId(id).get("value")){
                                    current_grid.model.set(fn_object.rid,form_object_select);
                                }
                            }
                        }
                    }

                    var check_if_dirty = current_grid.model.getChanged();

                    if(check_if_dirty.length > 0){

                        current_grid.model.save();

                        setTimeout(function(){
                            registry.byId("dialog_modify_progress_"+fn_object.rid).set({indeterminate: false, label: "Modified entry entry successfully!", value: 100});
                        },500);

                        setTimeout(function(){
                            setGridFilter(current_grid,{});
                            registry.byId("dialog_modify_"+fn_object.rid).hide();
                        },2000);
                    }
                }
            });

            var dialog_modify_progress = new ProgressBar({
                id: "dialog_modify_progress_"+fn_object.rid,
                style:"width:100%;", 
                value: ""
            });

            ////
            // Display
            ////

            var tab_container = new TabContainer({ style:"width: 445px;",doLayout:false });

            // Tab 1

            var t1 = new ContentPane({ title:"Modify",style:"padding:0" }).placeAt(tab_container);

            var t1_object = new Object();

            t1_object["0"] = domConstruct.create('table', {border:"0",style:{width:"100%"}},t1.containerNode);
            t1_object["1"] = domConstruct.create('tbody', {},t1_object["0"]);
            t1_object["2"] = domConstruct.create('tr', {},t1_object["1"]);
            t1_object["3"] = domConstruct.create('td', {colSpan:'2',style:{padding:"15px"}},t1_object["2"]);
            t1_object["4"] = domConstruct.create('span', {innerHTML:"Complete the following to MODIFY the selected entry:"},t1_object["3"]);

            var required_object = new Object();

            for (var i in res){

                  if(res[i].protected != 1){

                    var nameC = res[i].description;

                    required_object[i] = domConstruct.create('tr', {},t1_object["1"]);
                    required_object[i+"a"] =domConstruct.create('td', {style:{textAlign:"right",padding:"5px",width:"40%"}},required_object[i]);
                    domConstruct.create('span', {innerHTML:nameC+":"},required_object[i+"a"]);
                    required_object[i+"b"] = domConstruct.create('td', {colSpan:'2',style:{textAlign:"left",paddingLeft:"10px",width:"60%"}},required_object[i]);
                    registry.byId("dialog_modify_form_object_"+fn_object.rid+"_"+i).placeAt(required_object[i+"b"]);
                }
            }

            t1_object["5"] = domConstruct.create('tr', {},t1_object["1"]);
            t1_object["6"] = domConstruct.create('td', {colSpan:'2',style:{padding:"15px",textAlign:"center"}},t1_object["5"]);

            dialog_modify_button.placeAt(t1_object["6"]);
            t1_object["7"] = domConstruct.create('tr', {},t1_object["1"]);
            t1_object["8"] = domConstruct.create('td', {colSpan:'2',style:{textAlign:"center"}},t1_object["7"]);
            dialog_modify_progress.placeAt(t1_object["8"]);

            // Tab 2

            var dialog_delete_button = new Button({
                id: "dialog_delete_button_"+fn_object.rid,
                label: "Delete",
                onClick: function(){
                    
                    domStyle.set(registry.byId("dialog_delete_progress_"+fn_object.rid).domNode, "display", "block");
                    registry.byId("dialog_delete_progress_"+fn_object.rid).set({indeterminate: true, maximum: 100, label: 'Loading...'});


                    // Create a form to handle Grid Data
                    var form = document.createElement("form");
                    form.setAttribute("id", "delete_form");
                    form.setAttribute("name", "delete_form");
                    dojo.body().appendChild(form);
                        
                    var rid_element = document.createElement("input");
                    rid_element.setAttribute("type", "hidden");
                    rid_element.setAttribute("name", "rid");
                    rid_element.setAttribute("value", fn_object.rid);
                    form.appendChild(rid_element);

                    xhr.post(main_uri+"/delete", {
                        data: domForm.toObject("delete_form"),
                        handleAs: "text"
                    }).then(function(response){

                        setGridFilter('gridx_Grid_0',{});
                        cache_store.remove("filter");

                        // Remove Form
                        dojo.body().removeChild(form);
                        
                        //Stop ProgressBar
                        registry.byId("dialog_delete_progress_"+fn_object.rid).set({indeterminate: false, label: response, value: 100});
                   
                        setTimeout(function(){
                            registry.byId('dialog_modify_'+fn_object.rid).hide();
                        },1500);

                    }, function(error){
                        console.log("An error occurred: " + error);
                        return error;
                    });
                }
            });

            var dialog_delete_progress = new ProgressBar({
                id: "dialog_delete_progress_"+fn_object.rid,
                style:"width:100%;", 
                value: ""
            });

            var t2 = new ContentPane({ title:"Delete",style:"padding:0" }).placeAt(tab_container);

            var t2_object = new Object();

            t2_object["0"] = domConstruct.create('table', {border:"0",style:{width:"100%"}},t2.containerNode);
            t2_object["1"] = domConstruct.create('tbody', {},t2_object["0"]);
            t2_object["2"] = domConstruct.create('tr', {},t2_object["1"]);
            t2_object["3"] = domConstruct.create('td', {style:{padding:"15px"}},t2_object["2"]);
            domConstruct.create('span', {innerHTML:"Delete this entry from the inventory?"},t2_object["3"]);


            t2_object["4"] = domConstruct.create('tr', {},t2_object["1"]);
            t2_object["5"] = domConstruct.create('td', {style:{padding:"15px",textAlign:"center"}},t2_object["4"]);
            dialog_delete_button.placeAt(t2_object["5"]);
            t2_object["6"] = domConstruct.create('tr', {},t2_object["1"]);
            t2_object["7"] = domConstruct.create('td', {style:{textAlign:"center"}},t2_object["6"]);
            dialog_delete_progress.placeAt(t2_object["7"]);

            registry.byId("dialog_modify_"+fn_object.rid).set("content",tab_container);
        });
    }

    function populateModifyDialog(fn_object){
        
        // Show Dialog
        var dialog_modify = registry.byId('dialog_modify_'+fn_object.rid);

        if(!dialog_modify){
            dialog_modify = createDialog({ rid: "dialog_modify_"+fn_object.rid,title: "Modify Entry"});
            createModifyDialog(fn_object);
        }

        dialog_modify.show();

        // Progress Bar
        registry.byId("dialog_modify_progress_"+fn_object.rid).set({indeterminate: false, maximum: 100, label: "",value: ""});
        domStyle.set(registry.byId("dialog_modify_progress_"+fn_object.rid).domNode, "display", "none");   

        registry.byId("dialog_delete_progress_"+fn_object.rid).set({indeterminate: false, maximum: 100, label: "",value: ""});
        domStyle.set(registry.byId("dialog_delete_progress_"+fn_object.rid).domNode, "display", "none");   

        xhr.get(main_uri+"/stuff_tracker/"+fn_object.rid, {
            handleAs: "json",
            timeout: 5000,
            preventCache: false
        }).then(function(json_text){

            var json_obj = json_text[0];

            fetchColumns.then(function(res){
 
                for (var i in res){

                    var id    = "dialog_modify_form_object_"+fn_object.rid+"_"+i;
                    var type  = res[i].type;

                    if( (type == "varchar") || (type == "date") || (type == "integer") ){
                        if(res[i].protected != 1){
                            registry.byId(id).set("value",json_obj[res[i].name]);
                        }
                    }
                    if(type == "select"){
                        registry.byId(id).set("displayedValue",json_obj[res[i].name]);
                    }

                }
            });
        }, function(error){
            console.log("An error occurred: " + error);
            return error;
        });
    }

    function createFilterDialog(fn_object){

        fetchColumns.then(function(res){

            for (var i in res){

                var id    = "dialog_filter_form_object_"+i;
                var cid   = "dialog_filter_form_object_c"+i;
                var type  = res[i].type;
                var nameC = res[i].description;

                if( (!registry.byId('dialog_filter_form_object_'+i)) && (!registry.byId('dialog_filter_form_object_c'+i)) ){

                    if(type == "varchar"){
                        new TextBox({id: id,name: id,placeHolder: "Filter by "+nameC,disabled: true });
                    }
                    if(type == "integer"){
                        if(res[i].protected != 1){
                            new NumberSpinner({ id: id, name: id, placeHolder: "Filter by "+nameC, disabled: true, constraints: {min:1, places:0} });
                        }
                    }
                    if(type == "select"){

                        var url  = main_uri+"/filtering_select/"+res[i].id+"/";

                        new FilteringSelect({ 
                            id: id, 
                            name: id, 
                            value: "", 
                            required: false, 
                            placeHolder: "Filter by "+nameC,
                            store: JsonRest({target:url}),
                            disabled: true
                        });
                    }
                    if(type == "date"){
                        new DateTextBox({id:id,name:id,placeHolder:nameC+" - Start",disabled:true});
                        var eid  = "dialog_filter_form_object_end"+i;
                        new DateTextBox({id:eid,name:eid,placeHolder:nameC+" - End",disabled:true});
                    }
                    new CheckBox({ 
                        id: cid, 
                        name: cid, 
                        onChange: function(b){
                            var order = this.id.replace("dialog_filter_form_object_c","")
                            if(b){
                                registry.byId("dialog_filter_form_object_"+order).set("disabled", false);
                                if(registry.byId("dialog_filter_form_object_end"+order)){
                                    registry.byId("dialog_filter_form_object_end"+order).set("disabled", false);
                                }
                            }
                            else{
                                registry.byId("dialog_filter_form_object_"+order).set("disabled", true);
                                if(registry.byId("dialog_filter_form_object_end"+order)){
                                    registry.byId("dialog_filter_form_object_end"+order).set("disabled", true);
                                }
                            }
                        }
                    });
                }
            }
           
            // Integrated By
            if(!registry.byId('dialog_filter_form_object_integrated_by')){

                new FilteringSelect({ 
                    id: "dialog_filter_form_object_integrated_by", 
                    name: "dialog_filter_form_object_integrated_by", 
                    value: "", 
                    required: false, 
                    placeHolder: "Filter by Integrator",
                    store: JsonRest({target:main_uri+"/filtering_select/integrated_by/"}),
                    disabled: true
                });

                new CheckBox({ 
                    id: "dialog_filter_form_object_integrated_by_c", 
                    name: "dialog_filter_form_object_integrated_by_c", 
                    onChange: function(b){
                        if(b){
                            registry.byId("dialog_filter_form_object_integrated_by").set("disabled", false);
                        }
                        else{
                            registry.byId("dialog_filter_form_object_integrated_by").set("disabled", true);
                        }
                    }
                });
            }

            // Updated By
            if(!registry.byId('dialog_filter_form_object_updated_by')){

                new FilteringSelect({ 
                    id: "dialog_filter_form_object_updated_by", 
                    name: "dialog_filter_form_object_updated_by", 
                    value: "", 
                    required: false, 
                    placeHolder: "Filter by Updater",
                    store: JsonRest({target:main_uri+"/filtering_select/updated_by/"}),
                    disabled: true
                });

                new CheckBox({ 
                    id: "dialog_filter_form_object_updated_by_c", 
                    name: "dialog_filter_form_object_updated_by_c", 
                    onChange: function(b){
                        if(b){
                            registry.byId("dialog_filter_form_object_updated_by").set("disabled", false);
                        }
                        else{
                            registry.byId("dialog_filter_form_object_updated_by").set("disabled", true);
                        }
                    }
                });
            }

            var dialog_filter_button1 = new Button({
                label: "Filter",
                onClick: function(){

                    var query = {}; 

                    if(query["id"]){
                        delete query["id"];
                    }

                    for (var i in res){

                        var id   = "dialog_filter_form_object_"+i;
                        var cid  = "dialog_filter_form_object_c"+i;
                        var eid  = "dialog_filter_form_object_end"+i;
                        var type = res[i].type;

                        if(registry.byId(cid).get("checked") == true){
                            if(type == "select"){
                                query[ res[i].name+"_id" ] = registry.byId(id).get("value");
                            }
                            else{
                                if(type == "date"){
                                    if(registry.byId(id).get("value")){
                                        query[ res[i].name ] = common.format_date(registry.byId(id).get("value"));
                                    }
                                    if(registry.byId(eid).get("value")){
                                        query[ res[i].name+"_end" ] = common.format_date(registry.byId(eid).get("value"));
                                    }
                                }
                                else{
                                    if(res[i].protected != 1){
                                        query[ res[i].name ] = registry.byId(id).get("value");
                                    }
                                }
                            }
                        }
                    }

                    // Integrated By
                    if(registry.byId("dialog_filter_form_object_integrated_by_c").get("checked") == true){
                        query[ "integrated_by" ] = registry.byId("dialog_filter_form_object_integrated_by").get("value");
                    }

                    // Updated By
                    if(registry.byId("dialog_filter_form_object_updated_by_c").get("checked") == true){
                        query[ "updated_by" ] = registry.byId("dialog_filter_form_object_updated_by").get("value");
                    }

                    registry.byId('gridx_Grid_0').filter.setFilter( 
                        Filter.contain(
                            Filter.column('advanced_search'),
                            Filter.value(ioQuery.objectToQuery(query))
                        ) 
                    );
                    cache_store.put({ id:"filter", query: query });
                }
            });

            var dialog_filter_button2 = new Button({
                label: "Clear",
                onClick: function(){

                    cache_store.remove("filter");
                    setGridFilter('gridx_Grid_0',{});

                    for (var i in res){

                        var id    = "dialog_filter_form_object_"+i;
                        var cid   = "dialog_filter_form_object_c"+i;
                        var type  = res[i].type;

                        registry.byId(cid).set("checked",false);


                        if( (type == "varchar") || (type == "integer") || (type == "date") ){
                            if(res[i].protected != 1){
                                registry.byId(id).set("value",null);
                            }
                        }
                        if(type == "select"){
                            registry.byId(id).set("displayedValue",null);
                        }
                    }
                    registry.byId("dialog_filter_form_object_integrated_by_c").set("checked",false);
                    registry.byId("dialog_filter_form_object_integrated_by").set("value",null);
                    registry.byId("dialog_filter_form_object_updated_by_c").set("checked",false);
                    registry.byId("dialog_filter_form_object_updated_by").set("value",null);
                }
            });

            ////
            // Display
            ////

            var content_pane = new ContentPane();

            var cp_object = new Object();

            cp_object["0"] = domConstruct.create('table', {border:"0",style:{width:"400px"}},content_pane.containerNode);
            cp_object["1"] = domConstruct.create('tbody', {},cp_object["0"]);
            cp_object["2"] = domConstruct.create('tr', {},cp_object["1"]);
            cp_object["3"] = domConstruct.create('td', {colSpan:'3',style:{padding:"15px"}},cp_object["2"]);
            cp_object["4"] = domConstruct.create('span', {innerHTML:"Complete the following to FILTER the entries"},cp_object["3"]);

            var required_object = new Object();

            for (var i in res){
                if(res[i].protected != 1){

                    var nameC = res[i].description;

                    required_object[i] = domConstruct.create('tr', {},cp_object["1"]);
                    required_object["a"+i] = domConstruct.create('td', {style:{textAlign:"right",padding:"5px"}},required_object[i]);
                    registry.byId("dialog_filter_form_object_c"+i).placeAt(required_object["a"+i]);

                    required_object["b"+i] = domConstruct.create('td', {style:{textAlign:"right",padding:"5px",width:"40%"}},required_object[i]);
                    domConstruct.create('span', {innerHTML:nameC+":"},required_object["b"+i]);

                    required_object["c"+i] = domConstruct.create('td', {colSpan:'2',style:{textAlign:"left",paddingLeft:"10px",width:"60%"}},required_object[i]);
                    registry.byId("dialog_filter_form_object_"+i).placeAt(required_object["c"+i]);

                    if(registry.byId("dialog_filter_form_object_end"+i)){
                        domConstruct.create('div', {style:{padding:"1px"}},required_object["c"+i]);
                        registry.byId("dialog_filter_form_object_end"+i).placeAt(required_object["c"+i]);
                        domConstruct.create('div', {style:{padding:"1px"}},required_object["c"+i]);
                    }
                }
            }

            required_object["integrated_by_1"] = domConstruct.create('tr', {},cp_object["1"]);
            required_object["integrated_by_2"] = domConstruct.create('td', {style:{textAlign:"right",padding:"5px"}},required_object["integrated_by_1"]);
            registry.byId("dialog_filter_form_object_integrated_by_c").placeAt(required_object["integrated_by_2"]);

            required_object["integrated_by_3"] = domConstruct.create('td', {style:{textAlign:"right",padding:"5px",width:"40%"}},required_object["integrated_by_1"]);
            domConstruct.create('span', {innerHTML:"Integrated By:"},required_object["integrated_by_3"]);

            required_object["integrated_by_4"] = domConstruct.create('td', {colSpan:'2',style:{textAlign:"left",paddingLeft:"10px",width:"60%"}},required_object["integrated_by_1"]);
            registry.byId("dialog_filter_form_object_integrated_by").placeAt(required_object["integrated_by_4"]);

            required_object["updated_by_1"] = domConstruct.create('tr', {},cp_object["1"]);
            required_object["updated_by_2"] = domConstruct.create('td', {style:{textAlign:"right",padding:"5px"}},required_object["updated_by_1"]);
            registry.byId("dialog_filter_form_object_updated_by_c").placeAt(required_object["updated_by_2"]);

            required_object["updated_by_3"] = domConstruct.create('td', {style:{textAlign:"right",padding:"5px",width:"40%"}},required_object["updated_by_1"]);
            domConstruct.create('span', {innerHTML:"Updated By:"},required_object["updated_by_3"]);

            required_object["updated_by_4"] = domConstruct.create('td', {colSpan:'2',style:{textAlign:"left",paddingLeft:"10px",width:"60%"}},required_object["updated_by_1"]);
            registry.byId("dialog_filter_form_object_updated_by").placeAt(required_object["updated_by_4"]);

            cp_object["5"] = domConstruct.create('tr', {},cp_object["1"]);
            cp_object["6"] = domConstruct.create('td', {colSpan:'3',style:{textAlign:"center"}},cp_object["5"]);
            domConstruct.create('hr', {"class":"style-six"},cp_object["6"]);

            cp_object["7"] = domConstruct.create('tr', {},cp_object["1"]);
            cp_object["8"] = domConstruct.create('td', {colSpan:'3',style:{textAlign:"center"}},cp_object["7"]);
            dialog_filter_button1.placeAt(cp_object["8"]);
            dialog_filter_button2.placeAt(cp_object["8"]);

            registry.byId("dialog_filter").set("content",content_pane);
        });
    }

    function createAdminDialog(){

        fetchColumns.then(function(res){

            function createGrid(fn_object){

                var grid_layout = [
                    {name:"Status", field:"status", width: "55px", style: "text-align:center;", editable: true,alwaysEditing: true,
                        editor: "dijit.form.CheckBox",
                        editorArgs: {
                            props: 'value: true'
                        }
                    }
                ];

                if(fn_object.column_admin == 1){

                    grid_layout.push(
                        {
                            name:"Type", field:"type", width: "60px", style: "text-align:center;color:gray;font-style:italic", editable: false,
                            editor: FilteringSelect,
                            editorArgs: {
                                props: 'store: column_type_store_select_cache',
                                fromEditor: function(valueInEditor, cell){
                                    var obj = memory_store_99.get(valueInEditor);
                                    return obj.name;
                                },
                                toEditor: function(storeData, gridData, cell, editor){
                                    return 1;
                                }
                            }
                        },
                        {name:"Size (px)", field:"size", width: "50px", style: "text-align:center;", editable: true, 
                         editor: NumberSpinner,
                         editorArgs: { props:'smallDelta: 10, constraints: { min:100, max:600, places:0 }'}
                        },
                        {name:"Order", field:"order", width: "50px", style: "text-align:center;", editable: true, 
                         editor: NumberSpinner,
                         editorArgs: { props:'constraints: { min:1, places:0 }'}
                        },
                        {name:"Description", field:"description", width: "auto", editable: true}
                    );
                }
                else{
                    grid_layout.push({name:"Description", field:"description", width: "auto", style: "text-align:left;", editable: true});
                }

                var grid = new Grid({ 
                    cacheClass: Cache,
                    style:"width:100%;height:100%",
                    store: fn_object.store,
                    structure: grid_layout,
                    selectRowTriggerOnCell: true,
                    modules: [
                        "gridx/modules/VirtualVScroller",
                        "gridx/modules/CellWidget",
                        "gridx/modules/Edit",
                        "gridx/modules/SingleSort"
                    ],
                    editLazySave: true
                });

                var fe = new Object();

                fe["0"] = new TextBox({ 
                    id: "dialog_admin_add_textbox_"+fn_object.id, 
                    name: "dialog_admin_add_textbox_"+fn_object.id, 
                    placeHolder: "Add Description",
                    maxlength: 100,
                    style:"width:170px;margin-left:3px;margin-right:3px"
                });

                if(fn_object.column_admin == 1){
                    fe[0].set("maxlength",50);
                    fe[0].set("style","width:130px;margin-right:3px");
                }

                fe["1"] = new FilteringSelect({ 
                    id: "dialog_admin_add_select_"+fn_object.id, 
                    name: "dialog_admin_add_select_"+fn_object.id, 
                    value: "", 
                    required: false, 
                    placeHolder: "Select Type",
                    store: column_type_store_select,
                    style:"width: 90px;margin-left:3px;margin-right:3px"
                });

                fe["2"] = new Button({
                    id: "dialog_admin_add_button_"+fn_object.id,
                    label: "Add",
                    onClick: function(){

                        // Create a form to handle Grid Data
                        var form = document.createElement("form");
                        form.setAttribute("id", "admin_unprocessed");
                        form.setAttribute("name", "admin_unprocessed");
                        dojo.body().appendChild(form);
                            
                        var element_1 = document.createElement("input");
                        element_1.setAttribute("type", "hidden");
                        element_1.setAttribute("name", "column_id");
                        element_1.setAttribute("value", fn_object.id);
                        form.appendChild(element_1);

                        if(registry.byId("dialog_admin_add_textbox_"+fn_object.id).get("value") == ""){
                            // Remove Form
                            dojo.body().removeChild(form);
                            alert("Description is empty");
                            return false;
                        }

                        var element_2 = document.createElement("input");
                        element_2.setAttribute("type", "hidden");
                        element_2.setAttribute("name", "description");
                        element_2.setAttribute("value", registry.byId("dialog_admin_add_textbox_"+fn_object.id).get("value"));
                        form.appendChild(element_2);

                        if(fn_object.column_admin == 1){

                            if(registry.byId("dialog_admin_add_select_"+fn_object.id).get("value") == ""){
                                // Remove Form
                                dojo.body().removeChild(form);
                                alert("Type is empty");
                                return false;
                            }

                            var element_3 = document.createElement("input");
                            element_3.setAttribute("type", "hidden");
                            element_3.setAttribute("name", "type");
                            element_3.setAttribute("value", registry.byId("dialog_admin_add_select_"+fn_object.id).get("value"));
                            form.appendChild(element_3);
                        }

                        var url = "/admin_add";

                        if(fn_object.column_admin == 1){
                            url = "/add_column";
                        }
                        
                        xhr.post(main_uri+url, {
                            data: domForm.toObject("admin_unprocessed"),
                            handleAs: "text"
                        }).then(function(response){
                            
                            setGridFilter(grid.id,{});
                            cache_store.remove("filter");

                            if(fn_object.column_admin == 1){
                                fe["4"].set("disabled", false);
                            }

                            dojo.body().removeChild(form);

                        }, function(error){
                            console.log("An error occurred: " + error);
                            return error;
                        });
                    }
                });

                fe["3"] = new Button({
                    id: "dialog_admin_clear_button_"+fn_object.id,
                    label: "Clear",
                    style: "padding-right:3px",
                    onClick: function(){
                        registry.byId("dialog_admin_add_textbox_"+fn_object.id).set("value",null);
                        if(fn_object.column_admin == 1){
                            registry.byId("dialog_admin_add_select_"+fn_object.id).set("displayedValue",null);
                        }
                    }
                });

                fe["4"] = new Button({
                    label: "Reload Page!",
                    disabled: true,
                    onClick: function(){
                        location.reload(true);
                    }
                });

                var t = new Object();

                t["0"] = new BorderContainer({gutters:true,style:"padding: 0;width:435px;height:380px;"}).placeAt(fn_object.container);

                // Top Pane
                t["1"] = new ContentPane({region:"top",style:"background-color: #F8F8F8;height:32px;padding:0;"}).placeAt(t["0"]);
                t["2"] = domConstruct.create('table', {border:"0",style:{width:"100%",whiteSpace:"nowrap"}},t["1"].containerNode);
                t["3"] = domConstruct.create('tbody', {},t["2"]);
                t["4"] = domConstruct.create('tr', {},t["3"]);
                t["5"] = domConstruct.create('td', {style:{textAlign:"center"}},t["4"]);

                if(fn_object.column_admin == 1){
                    fe["1"].placeAt(t["5"]);
                }

                fe["0"].placeAt(t["5"]);
                fe["2"].placeAt(t["5"]);
                fe["3"].placeAt(t["5"]);
                if(fn_object.column_admin == 1){
                    domConstruct.create('span', {style:{padding:"1px",borderLeft:"1px dotted silver"}},t["5"]);
                    fe["4"].placeAt(t["5"]);
                }

                t["6"] = new ContentPane({region:"center",splitter:false,style:"padding:0;border:0"}).placeAt(t["0"]);

                grid.placeAt(t["6"]);

                grid.edit.connect(grid.edit, "onApply", function(cell, success) {
                    var check_if_dirty = grid.model.getChanged();
                    if(check_if_dirty.length > 0){
                            fe["4"].set("disabled", false);
                        for	(var index = 0; index < check_if_dirty.length; index++) {
                            grid.model.save();
                        } 
                    }
                });
            }

            var tc = new TabContainer({doLayout:true, tabStrip:true, style:"width:455px;height:420px;"});

            // Tab 1
            var t1 = new ContentPane({title:"Main Columns",style:"padding:5px;"}).placeAt(tc);
            var c  = new ContentPane({title:"Columns",style:"padding:0;"}).placeAt(t1);
            createGrid({id:0,store:column_store,container:c,name:"Columns",column_admin:1});

            // Tab 2
            var t2 = new TabContainer({title:"Selects/Drop-Down",doLayout:true, tabPosition:"left-h", tabStrip:true,style:"padding:5px"}).placeAt(tc);
            for (var i in res){
                var type  = res[i].type;
                if(type == "select"){
                    var nameC = res[i].description;
                    var c = new ContentPane({title:nameC}).placeAt(t2);
                    createGrid({id:res[i].id,store:JsonRest({target:main_uri+"/admin_grid/"+res[i].id}),container:c,name:nameC});
                }
            }

            registry.byId("dialog_admin").set("content",tc);
        });
    }

    ///////////////////////////////////////////////////////////////////////////

    ////
    // Custom Functions
    //// 
  
    ///////////////////////////////////////////////////////////////////////////

    ////
    // Grids
    ////
   
    function createServiceTab(fn_object) {

        fetchColumns.then(function(res){

            var grid_layout = [
                { name:"--", field:"id", width: "50px", style: "font-size: 8pt;text-align:center;",
                    widgetsInCell: true,
                    decorator: function(){
                        declare("manage_link", [_WidgetBase], {
                            buildRendering: function(){
                                this.domNode = domConstruct.create("span", {"class": "cellLink",style:{cursor:"pointer",padding:"0 3px 0 3px"},innerHTML: 'Modify'});
                            }
                        });
                        return '<div data-dojo-type="manage_link" data-dojo-attach-point="manage_link_click"></div>';
                    },
                    getCellWidgetConnects: function(cellWidget, cell){
                        return [
                            [cellWidget.manage_link_click.domNode, 'onclick', function(e){
                                var cell_data = registry.byId(cell.grid.id).model.byId(cell.data());
                                populateModifyDialog({rid: cell.data(), cell_data: cell_data });
                            }]
                        ];
                    }
                }
            ];

            var select_stores = new Object();
            var select_array  = new Array();

            for(var i in res){

                var nameC = res[i].description;
                var order = res[i].order + 1;
                var size  = res[i].size + 'px';

                if(res[i].type == "varchar"){
                    grid_layout.splice(order,0,{ name: nameC, field: res[i].name, width: size, style: "text-align:center;", editable: true });
                }
                if(res[i].type == "integer"){
                    if(res[i].name == "integrated_by"){
                        grid_layout.splice(order,0,{ name: nameC, field: "integrated_by_name", width: size, style: "text-align:center;", editable: false });
                    }
                    else if(res[i].name == "updated_by"){
                        grid_layout.splice(order,0,{ name: nameC, field: "updated_by_name", width: size, style: "text-align:center;", editable: false });
                    }
                    else{ 
                        grid_layout.splice(order,0,{ name: nameC, field: res[i].name, width: size, style: "text-align:center;", editable: true,
                            editor: NumberSpinner,
                            editorArgs: { props:'constraints: { min:1, places:0 }'}
                        });
                    }
                }
                if(res[i].type == "date"){
                    grid_layout.splice(order,0,{ 
                        name: nameC, field: res[i].name, width: size, style: "text-align:center;", editable: true, 
                        editor: DateTextBox,
                        editorArgs: {
                            fromEditor: function(valueInEditor, cell){
                                return common.format_date(valueInEditor);
                            },
                            toEditor: function(storeData, gridData, cell){
                                return 1;
                            }
                        }
                    });
                }
                if(res[i].type == "select"){
                    grid_layout.splice(order,0,addGridSelectSlice({id: res[i].id, name: res[i].name, description: res[i].description, size: size}));

                }
            }

            for	(var index = 0; index < select_array.length; index++) {

                var select_store   = JsonRest({target:main_uri+"/filtering_select/"+select_array[index].id+"/?name=*"});
                var memory_store   = new Memory();

                select_store_cache = new dojoCache(select_store,memory_store);   
            }

            // Grid
            
            var service_grid  = new Grid({ 
                cacheClass: Cache,
                style:"width:100%;height:100%",
                store: fn_object.store,
                structure: grid_layout,
                query: fn_object.query,
                selectRowTriggerOnCell: true,
                paginationBarMessage: "${2} to ${3} of <span style='font-size:12pt;color:red'><strong>${0}</strong></span> items ${1} items selected",
                filterServerMode: true,
                filterSetupFilterQuery: function(expr){
                    if(fn_object.query){
                        var s = lang.clone(fn_object.query);
                        if(expr.data[0].data == 'advanced_search'){
                            return ioQuery.queryToObject(expr.data[1].data);
                        }
                        if(expr.data[0].data == 'search'){
                            s.query = expr.data[1].data;
                            return s;
                        }
                    }
                },
                modules: [
                    "gridx/modules/Filter",
                    "gridx/modules/VirtualVScroller",
                    "gridx/modules/CellWidget",
                    "gridx/modules/Edit",
                    "gridx/modules/SingleSort",
                    "gridx/modules/ColumnResizer",
                    "gridx/modules/Pagination",
                    "gridx/modules/pagination/PaginationBar"
                ],
                editLazySave: true
            });

            service_grid.edit.connect(service_grid.edit, "onApply", function(cell, success) {

                var check_if_dirty = service_grid.model.getChanged();
                                
                if(check_if_dirty.length > 0){
                    for	(var index = 0; index < check_if_dirty.length; index++) {
                        service_grid.model.save();
                    } 
                }
            });

            var mc = registry.byId("main_container");
            service_grid.placeAt(mc);
        });
    }

    // Filter Clear

    function setGridFilter(grid,obj){
        registry.byId(grid).model.clearCache(); 
        registry.byId(grid).model.query(obj);
        registry.byId(grid).body.refresh();
    }

    function capitalizeFirstLetter(string) {
        return string.charAt(0).toUpperCase() + string.slice(1);
    }

    function formatString(string) {
        var result = capitalizeFirstLetter(string);
        if((string).indexOf('_') > -1){
            array1 = (string).split("_");
            array2 = new Array();
            for (index = 0; index < array1.length; index++) {
                array2.push(capitalizeFirstLetter(array1[index]));
            }
            result = array2.join(" ");
        }
        return result;
    }

    function addGridSelectSlice(fn_object){

        var id    = fn_object.id;
        var name  = fn_object.name;
        var nameC = fn_object.description;
        var size  = fn_object.size;

        var select_store   = new JsonRest({target:main_uri+"/filtering_select/"+id+"/"});
        var memory_store   = new Memory();
        select_store_cache = new dojoCache(select_store,memory_store);

        when (select_store_cache.query({name:"*"}),
          function (items, request) {
          }
        );

        var obj = { 
            name: nameC, field:name, width: size, style: "text-align:center;", editable: true,
            editor: FilteringSelect,
            editorArgs: {
                props: 'store: select_store_cache',
                fromEditor: function(valueInEditor, cell){
                    var obj = memory_store.get(valueInEditor);
                    return obj.name;
                },
                toEditor: function(storeData, gridData, cell, editor){
                    editor.set({store: memory_store});
                    return 1;
                }
            }
        };
        return obj;
    }
});
