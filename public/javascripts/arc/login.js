
require([
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
], function( domAttr, dom, domConstruct, BorderContainer, ContentPane, Form, Button, TextBox, common ){

    const main_uri   = domAttr.get(dom.byId("main_uri"),"value");
    const static_uri = domAttr.get(dom.byId("static_uri"),"value");
    const err        = domAttr.get(dom.byId("err"),"value");

    const username = new TextBox({ id: "username", name: "username", placeHolder: "Username" });
    const password = new TextBox({ id: "password", name: "password", type: "password", placeHolder: "Password" });

    const button = new Button({
        id: "login_button",
        name: "login_button",
        label: "Login",
        type: "submit"
    });

    const link2 = common.create_link_widget('Need to change password?',function(){
        window.location = main_uri+"/change_password";
    });

    const cp = new ContentPane({region:"center",style:"background-color:#f8f8f8;padding:0;width:385px;height:215px;border:1px solid silver;margin-left:auto;margin-right:auto;margin-top:100px"});

    const form = new Form({method: "POST"}).placeAt(cp.containerNode);

    const cp_object = new Object();

    cp_object["0"] = domConstruct.create('table', {border:"0",style:{width:"100%"}},form.containerNode);
    cp_object["1"] = domConstruct.create('tbody', {},cp_object["0"]);
    cp_object["2"] = domConstruct.create('tr', {},cp_object["1"]);
    cp_object["3"] = domConstruct.create('td', {colSpan:'2',style:{padding:"15px"}},cp_object["2"]);
    cp_object["4"] = domConstruct.create('span', {innerHTML:"Please enter Username/Password to Login."},cp_object["3"]);

    cp_object["5"] = domConstruct.create('tr', {},cp_object["1"]);
    cp_object["6"] = domConstruct.create('td', {style:{textAlign:"right",padding:"5px",width:"40%"}},cp_object["5"]);
    cp_object["7"] = domConstruct.create('span', {innerHTML:"Username"},cp_object["6"]);
    cp_object["8"] = domConstruct.create('td', {style:{textAlign:"left",paddingLeft:"10px",width:"60%"}},cp_object["5"]);
    username.placeAt(cp_object["8"]);

    cp_object["9"]  = domConstruct.create('tr', {},cp_object["1"]);
    cp_object["10"] = domConstruct.create('td', {style:{textAlign:"right",padding:"5px",width:"40%"}},cp_object["9"]);
    cp_object["11"] = domConstruct.create('span', {innerHTML:"Password"},cp_object["10"]);
    cp_object["12"] = domConstruct.create('td', {style:{textAlign:"left",paddingLeft:"10px",width:"60%"}},cp_object["9"]);
    password.placeAt(cp_object["12"]);

    cp_object["10"] = domConstruct.create('tr', {},cp_object["1"]);
    cp_object["11"] = domConstruct.create('td', {colSpan:"2",style:{padding:"10px",textAlign:"center"}},cp_object["10"]);
    button.placeAt(cp_object["11"]);

    cp_object["14"] = domConstruct.create('tr', {},cp_object["1"]);
    cp_object["15"] = domConstruct.create('td', {colSpan:"2",style:{textAlign:"center"}},cp_object["14"]);
    link2.placeAt(cp_object["15"]);

    cp_object["16"] = domConstruct.create('tr', {},cp_object["1"]);
    cp_object["17"] = domConstruct.create('td', {colSpan:"2"},cp_object["16"]);
    cp_object["18"] = domConstruct.create('hr', {"class":"style-six"},cp_object["17"]);

    cp_object["19"] = domConstruct.create('tr', {},cp_object["1"]);
    cp_object["20"] = domConstruct.create('td', {colSpan:"2",style:{padding:"5px",textAlign:"center"}},cp_object["19"]);
    cp_object["21"] = domConstruct.create('div', {innerHTML:"<strong>"+err+"</strong>"},cp_object["20"]);

    form.startup();
    cp.placeAt(document.body);
    cp.startup();

    dom.byId("username").focus();

    return cp;
});
