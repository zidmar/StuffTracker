
require([
    "dijit/registry",
    "dojo/dom-attr",
    "dojo/dom",
    "dojo/dom-construct",
    "dijit/layout/BorderContainer",
    "dijit/layout/ContentPane",
    "dijit/form/Form",
    "dijit/form/Button",
    "dijit/form/TextBox",
    "arc/common",
    "dojo/domReady!"
    
], function( registry, domAttr, dom, domConstruct, BorderContainer, ContentPane, Form, Button, TextBox, common ){

    var main_uri   = domAttr.get(dom.byId("main_uri"),"value");
    var static_uri = domAttr.get(dom.byId("static_uri"),"value");
    var err        = domAttr.get(dom.byId("err"),"value");

    var username  = new TextBox({ id: "username",  name: "username", placeHolder: "Username" });
    var password  = new TextBox({ id: "password",  name: "password",  type: "password", placeHolder: "Old Password" });
    var npassword = new TextBox({ id: "npassword", name: "npassword", type: "password", placeHolder: "New Password" });
    var cpassword = new TextBox({ id: "cpassword", name: "cpassword", type: "password", placeHolder: "Confirm New Password" });

    var button = new Button({
        id: "change_password_button",
        name: "change_password_button",
        label: "Change Password",
        type: "submit"
    });

    var link1 = common.create_link_widget('Go to Login page?',function(){
        window.location = main_uri+"/login";
    });

    var cp = new ContentPane({region:"center",style:"background-color:#f8f8f8;padding:0;width:385px;height:285px;border:1px solid silver;margin-left:auto;margin-right:auto;margin-top:100px"});

    var form = new Form({method: "POST"}).placeAt(cp.containerNode);

    var cp_object = new Object();

    cp_object["0"] = domConstruct.create('table', {border:"0",style:{width:"100%"}},form.containerNode);
    cp_object["1"] = domConstruct.create('tbody', {},cp_object["0"]);
    cp_object["2"] = domConstruct.create('tr', {},cp_object["1"]);
    cp_object["3"] = domConstruct.create('td', {colSpan:'2',style:{padding:"15px"}},cp_object["2"]);
    cp_object["4"] = domConstruct.create('span', {innerHTML:"Fillout the following fields to change password."},cp_object["3"]);

    cp_object["5"] = domConstruct.create('tr', {},cp_object["1"]);
    cp_object["6"] = domConstruct.create('td', {style:{textAlign:"right",padding:"5px",width:"40%"}},cp_object["5"]);
    cp_object["7"] = domConstruct.create('span', {innerHTML:"Username"},cp_object["6"]);
    cp_object["8"] = domConstruct.create('td', {style:{textAlign:"left",paddingLeft:"10px",width:"60%"}},cp_object["5"]);
    username.placeAt(cp_object["8"]);

    cp_object["9"]  = domConstruct.create('tr', {},cp_object["1"]);
    cp_object["10"] = domConstruct.create('td', {style:{textAlign:"right",padding:"5px",width:"40%"}},cp_object["9"]);
    cp_object["11"] = domConstruct.create('span', {innerHTML:"Old Password"},cp_object["10"]);
    cp_object["12"] = domConstruct.create('td', {style:{textAlign:"left",paddingLeft:"10px",width:"60%"}},cp_object["9"]);
    password.placeAt(cp_object["12"]);

    cp_object["13"] = domConstruct.create('tr', {},cp_object["1"]);
    cp_object["14"] = domConstruct.create('td', {colSpan:"2"},cp_object["13"]);
    cp_object["15"] = domConstruct.create('hr', {"class":"style-six"},cp_object["14"]);

    cp_object["16"] = domConstruct.create('tr', {},cp_object["1"]);
    cp_object["17"] = domConstruct.create('td', {style:{textAlign:"right",padding:"5px",width:"40%"}},cp_object["16"]);
    cp_object["18"] = domConstruct.create('span', {innerHTML:"New Password"},cp_object["17"]);
    cp_object["19"] = domConstruct.create('td', {style:{textAlign:"left",paddingLeft:"10px",width:"60%"}},cp_object["16"]);
    npassword.placeAt(cp_object["19"]);

    cp_object["20"] = domConstruct.create('tr', {},cp_object["1"]);
    cp_object["21"] = domConstruct.create('td', {style:{textAlign:"right",padding:"5px",width:"40%"}},cp_object["20"]);
    cp_object["22"] = domConstruct.create('span', {innerHTML:"Confirm New Password"},cp_object["21"]);
    cp_object["23"] = domConstruct.create('td', {style:{textAlign:"left",paddingLeft:"10px",width:"60%"}},cp_object["20"]);
    cpassword.placeAt(cp_object["23"]);

    cp_object["24"] = domConstruct.create('tr', {},cp_object["1"]);
    cp_object["25"] = domConstruct.create('td', {colSpan:"2",style:{padding:"10px",textAlign:"center"}},cp_object["24"]);
    button.placeAt(cp_object["25"]);

    cp_object["26"] = domConstruct.create('tr', {},cp_object["1"]);
    cp_object["27"] = domConstruct.create('td', {colSpan:"2",style:{textAlign:"center"}},cp_object["26"]);
    link1.placeAt(cp_object["27"]);

    cp_object["30"] = domConstruct.create('tr', {},cp_object["1"]);
    cp_object["31"] = domConstruct.create('td', {colSpan:"2"},cp_object["30"]);
    cp_object["32"] = domConstruct.create('hr', {"class":"style-six"},cp_object["31"]);

    cp_object["33"] = domConstruct.create('tr', {},cp_object["1"]);
    cp_object["34"] = domConstruct.create('td', {colSpan:"2",style:{padding:"5px",textAlign:"center"}},cp_object["33"]);
    cp_object["35"] = domConstruct.create('span', {innerHTML:"<strong>"+err+"</strong>"},cp_object["34"]);

    form.startup();

    cp.placeAt(document.body);
    cp.startup();
    
    dom.byId("username").focus();

    return cp;
});
