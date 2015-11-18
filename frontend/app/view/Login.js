Ext.define('Receipts.view.Login',{
    extend: 'Ext.tab.Panel',
    alias: 'widget.login',
    layout: 'fit',
    items: [
        { 
            xtype: 'form',
            title: __('login.loginTab'),
            url:'backend/auth/page/hashdb/login',
            errorReader: 'customreader',
            defaultType:'textfield',
            bodyPadding:10,
            labelWidth:200,
            items: [
                {
                    fieldLabel: __('login.username'),
                    name: 'username',
                    enableKeyEvents:true,
                    allowBlank:false
                },
                {
                    fieldLabel : __('login.password'),
                    name : 'password',
                    inputType:'password',
                    enableKeyEvents:true,
                    allowBlank:false
                }
            ],
            buttons:[{ 
                text:__('login.login'),
                name:'login'
            }]
        },
        { 
            xtype: 'form',
            name:'register',
            title: __('login.registerTab'),
            url:'backend/register',
            errorReader: 'customreader',
            defaultType:'textfield',
            bodyPadding:10,
            items: [
                {
                    fieldLabel: __('register.firstName'),
                    name: 'firstName',
                    allowBlank:false
                },
                {
                    fieldLabel : __('register.lastName'),
                    name:'lastName',
                    allowBlank:false
                },
                {
                    fieldLabel : __('register.organization'),
                    name:'organization',
                    allowBlank:false
                },
                {
                    fieldLabel: __('register.email'),
                    name:'email',
                    allowBlank:false
                },
                {
                    fieldLabel: __('register.deliveryEmail'),
                    name:'deliveryEmail',
                    allowBlank:false
                },
                {
                    name:'recaptchaResponse',
                    hidden:true
                },
                {
                    xtype:'panel',
                    layout:'fit',
                    border:true,
                    listeners: {
                        afterrender: function(c) {
                            var rr = c.up('form').down('[name=recaptchaResponse]'),
                                s = c.up('form').down('button[name=register]');


                            grecaptcha.render(Ext.getDom(c.body), {
                                sitekey : '6Lf57g8TAAAAAIqaiVdOACSNSL1Ipo_nWfvEFrmP',
                                callback: function (response) {
                                    s.enable();
                                    rr.setValue(response);
                                }
                            });

                        }
                    }
                }
            ],
            buttons:[{ 
                text:__('register.register'),
                name:'register',
                disabled:true
            }]
        }
    ]
});
