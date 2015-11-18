Ext.define('Receipts.controller.Login', {
    extend: 'Ext.app.Controller',
    views: ['Login', 'ResetPassword'],
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
            form = e.up('form'),
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
    doRegister: function(e) {
        var win = e.up('window'),
            form = e.up('form'),
            c = this;
        form.submit({
            method:'POST',
            waitTitle:__('register.waitTitle'),
            waitMsg:__('register.waitmessage'),
            headers: {
                'Accept': 'application/json'
            },
            jsonSubmit:true,
            success:function(e, f, action) {
                Ext.Msg.alert(__('register.successTitle'), __('register.successMessage'), function() { form.reset(); });
            },
            failure:function(form, action) {
                var extra = '';
                try {
                    var errorCode = JSON.parse(action.response.responseText)['error'];
                    extra = ": " + __('register.' + errorCode);
                } catch (e) {}
                Ext.Msg.alert(__('register.failedtitle'), __('register.failedMessage') + extra);
            }
        });
    },

    getQsVars: function() {
        var qs = document.location.href.split('?')[1];
        if (qs != undefined)
            return Ext.Object.fromQueryString(qs);
        else
            return {};
    },
    getSetUserPasswordUrl: function() {
        var qs = this.getQsVars();
        return 'backend/set-user-password/' + qs['userId'] + '/' + qs['token'];
    },
    doResetPassword: function(e) {
        var win = e.up('window'),
            form = win.down('form'),
            c = this,
            qsVars = c.getQsVars();

        form.submit({
            url:c.getSetUserPasswordUrl(),
            method:'POST',
            waitTitle:__('resetPassword.waitTitle'),
            waitMsg:__('resetPassword.waitmessage'),
            headers: {
                'Accept': 'application/json'
            },
            success:function(form, action) {
                win.close();
                Ext.Msg.alert(__('resetPassword.successTitle'),
                              __('resetPassword.successMessage'),
                              function() {
                    window.location.href = window.location.href.split("?")[0];
                });
            },
            failure:function(form, action) {
                Ext.Msg.alert(__('resetPassword.failedtitle'), __('resetPassword.failedmessage'));
            }
        });
    },
    showLoginWindow: function(xtype) {
        var win = new Ext.Window({
            id:xtype,
            title: __(xtype + '.title'),
            plain:true,
            border: false,
            closable:false,
            draggable:false,
            resizable:false,
            margin: '0 0 0 0',
            items: [{xtype:xtype}]
        });
        win.show();
 
    },
    checkResetPasswordMatch: function(tf) {

        var f = tf.up('form'),
            p1 = f.down('[name=password]'),
            p2 = f.down('[name=passwordAgain]'),
            s  = f.down('button');
        if (p1.getValue() == p2.getValue() && f.isValid())
            s.enable();
        else
            s.disable();
    },
                
    init: function() {

        var c = this;
        Receipts.GlobalState.on('ready', function() {
            var qs = document.location.href.split('?')[1];
            var qsVars = c.getQsVars();
            if ('token' in qsVars && 'userId' in qsVars) {
                Ext.Ajax.request({
                    url: c.getSetUserPasswordUrl(),
                    success: function(response) {
                        c.showLoginWindow('resetPassword');
                    },
                    failure: function(response) {
                        Ext.Msg.alert(__('resetPassword.tokenNotValidTitle'), __('resetPassword.tokenNotValid'), function() {
                            window.location.href = window.location.href.split("?")[0];
             
                        });
                    }
                });
            } else {
                c.showLoginWindow('login');
                c.loadUser();
            }
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
            'resetPassword textfield[name=password]' : {
                change: function(tf) {
                    c.checkResetPasswordMatch(tf);
                }
            },
            'resetPassword textfield[name=passwordAgain]' : {
                change: function(tf) {
                    c.checkResetPasswordMatch(tf);
                }
            },


            'login button[name=login]' : {
                click: function(button) {
                    c.doLogin(button);
                }
            },
            'login button[name=register]' : {
                click: function(button) {
                    c.doRegister(button);
                }
            },
            'resetPassword button[name=resetPassword]' : {
                click: function(button) {
                    c.doResetPassword(button);
                }
            }

        });
    }

});
