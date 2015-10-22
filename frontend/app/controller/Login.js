Ext.define('Receipts.controller.Login', {
    extend: 'Ext.app.Controller',
    views: ['Login'],
    loadUser: function() {
        Ext.Ajax.request({
            url: 'backend/',
            success: function(response){
                var win = Ext.getCmp('login');
                try {
                    var obj = JSON.parse(response.responseText)
                    if ("user" in obj) {
                        win.close();
                        Receipts.GlobalState.user = obj.user;
                        try {
                            Receipts.GlobalState.user.config = JSON.parse(obj.user.config);
                        } catch (e) {
                            console.log("Warning: invalid user config: " + e);
                        }
                        Ext.create('Ext.container.Viewport', {
                            layout: 'fit',
                            items: [
                                {
                                    xtype: 'app-main'
                                }
                            ]
                        });
                        $("#site-title").hide();
                        Ext.getStore('processperiods').load(function() {
                            Receipts.GlobalState.fireEvent('login');
                        });
                    }
                } catch (e) {
                    console.log(e);
                }
            }
        });
    },
    doLogin: function(e) {
        var win = e.up('window'),
            form = win.down('form'),
            c = this;
        form.submit({
            method:'POST',
            waitTitle:__('login.waittitle'),
            waitMsg:__('login.waitmessage'),
            headers: {
                'Accept': 'application/json'
            },
            success:function(form, action) {
                c.loadUser();
            },
            failure:function(form, action) {
                Ext.Msg.alert(__('login.failedtitle'), __('login.failedmessage'));
            }
        });
    },

    init: function() {

        var c = this;
        Receipts.GlobalState.on('ready', function() {
            var win = new Ext.Window({
                id:'login',
                layout: {
                    type: 'vbox',
                    align:'center',
                    pack:'center' 
                },
                title: __('login.title'),
                plain:true,
                border: false,
                closable:false,
                draggable:false,
                resizable:false,
                margin: '0 0 0 0',
                items: [{xtype:'login'}]
            });
            win.show()
            c.loadUser();
        });
        
        this.control({
           'login textfield[name=username]' : {
               keypress: function (tf, e, eOpts) {
                   if (e.keyCode == 13)
                       c.doLogin(tf);
               }
           },
           'login textfield[name=password]' : {
               keypress: function (tf, e, eOpts) {
                    if (e.keyCode == 13)
                       c.doLogin(tf);
               }
           },
            'login button[name=login]' : {
                click: function(button) {
                    c.doLogin(button);
                }
            }
        });
    }

});
