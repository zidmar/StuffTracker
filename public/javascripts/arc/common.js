
define(
[
    "dojo/_base/declare",
    "dojo/dom-construct",
    "dojo/date",
    "dijit/_WidgetBase",
    "dijit/registry",
    "dijit/layout/ContentPane",
    "dijit/ProgressBar",
    "dijit/Dialog",
    "dijit/form/ValidationTextBox"

],function(declare,domConstruct,date,_WidgetBase,registry,ContentPane,ProgressBar,Dialog,ValidationTextBox){

    var w = declare(null,{});

    w.last_updated = function(date_str){

        var js_month = new Array();
        js_month[1]  = 0;
        js_month[2]  = 1;
        js_month[3]  = 2;
        js_month[4]  = 3;
        js_month[5]  = 4;
        js_month[6]  = 5;
        js_month[7]  = 6;
        js_month[8]  = 7;
        js_month[9]  = 8;
        js_month[10] = 9;
        js_month[11] = 10;
        js_month[12] = 11;

        var re    = /(\d+)\,(\d+)\,(\d+)\,(\d+)\,(\d+)\,(\d+)/;
        var str   = date_str;
        var year  = str.replace(re, "$1");
        var month = str.replace(re, "$2");
            month = month.replace(/^0+/, '');
        var day   = str.replace(re, "$3");
            day   = day.replace(/^0+/, '');
        var hour  = str.replace(re, "$4");
            hour  = hour.replace(/^0+/, '');
        var min   = str.replace(re, "$5");
            min   = min.replace(/^0+/, '');
        var sec   = str.replace(re, "$6");
            sec   = sec.replace(/^0+/, '');

        var date1       = new Date();
        var date2       = new Date(year, js_month[month], day, hour, min, sec);
        var date_diff0  = date.difference(date2, date1, "second");
        var date_diff1  = date.difference(date2, date1, "minute");
        var date_diff2  = date.difference(date2, date1, "hour");
        var date_diff3  = date.difference(date2, date1, "day");
        var date_diff4  = date.difference(date2, date1, "month");
        var date_diff5  = date.difference(date2, date1, "year");

        var result = date_diff0+'s';

        if(date_diff0>60){
            result = date_diff1+'mi';
        }
        if(date_diff1>60){
            result = date_diff2+'h';
        }
        if(date_diff2>24){
            result = date_diff3+'d';
        }
        if(date_diff3>30){
            result = date_diff4+'m';
        }
        if(date_diff4>12){
            result = date_diff5+'y'
        }
        return result;
    }

    // Date formatter
    w.format_date = function (date_to_format){ 
        var formatted_date = dojo.date.locale.format(date_to_format, {
            formatLength: "long",
            selector: "date",
            datePattern: 'yyyy-MM-dd'
        });
        return formatted_date;
    }

    w.refresh_grid = function(grid,store,query){
        grid.model.clearCache();
        grid.model.query(query);
        grid.model.setStore(store);
        grid.body.refresh();
    }

    w.create_link_widget = function(name,exec){

        declare("filterWidget", [_WidgetBase], {
            buildRendering: function(){
                this.domNode = domConstruct.create("span", {"class": "cellLink",style: "cursor: pointer;padding:0 3px 0 3px;",innerHTML: name});
            },
            postCreate: function(){
                this.connect(this.domNode, "onclick", "exec_function");
            },
            exec_function: exec 
        });
        createdWidget = new filterWidget;
        return createdWidget;
    }

    w.validation_textbox = declare("gridx_ValidationTextBox",[ValidationTextBox], {
        regExp:'[\\w]+', 
        //invalidMessage:'Invalid character detected. Use "_" instead of spaces.'
        invalidMessage:'Invalid character detected!<br>Use underscore ( _ ) instead of spaces.'
    });

    w.finish_progress_dialog = function(){
        registry.byId("loading_progress_bar").set({indeterminate: false, label: "Done!", value: 100});
        setTimeout(function(){ 
            registry.byId('loading_dialog').hide();
        },500);
    }

    w.progress_dialog = function(name){

        function createDialog(){

            var cp = new ContentPane();

            var myProgressBar = new ProgressBar({
                id:"loading_progress_bar",
                style: "width: 300px",
                indeterminate: true,
                maximum: 100,
                label: "Loading..."
            }).placeAt(cp);

            var d = new Dialog({
                id: "loading_dialog",
                title: "Loading "+name+"...",
                content: cp
            });
            d.show(); 
        }

        var existing_dialog = registry.byId('loading_dialog');

        if(existing_dialog){ 
            existing_dialog.destroyRecursive();
            createDialog();
        }
        else{
            createDialog();
        }
    }

    return w;
});
