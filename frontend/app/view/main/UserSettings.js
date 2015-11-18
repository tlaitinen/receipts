Ext.define('Receipts.view.main.UserSettings',{
    extend: 'Ext.form.Panel',
    alias: 'widget.userSettings',
    items: [
        { 
            xtype: 'form',
            url: 'backend/db/settings',
            errorReader: 'customreader',
            name:'settings',
            defaultType:'textfield',
            bodyPadding:10,
            listeners: {
                afterrender: function (form) {
                    form.down('[name=firstName]').setValue(Receipts.GlobalState.user.firstName);
                    form.down('[name=lastName]').setValue(Receipts.GlobalState.user.lastName);
                    form.down('[name=organization]').setValue(Receipts.GlobalState.user.defaultUserGroupOrganization);
                    form.down('[name=deliveryEmail]').setValue(Receipts.GlobalState.user.defaultUserGroupEmail);
                }
            },
            items: [
                {
                    fieldLabel: __('settings.firstName'),
                    name: 'firstName',
                    allowBlank:false
                },
                {
                    fieldLabel : __('settings.lastName'),
                    name:'lastName',
                    allowBlank:false
                },
                {
                    fieldLabel : __('settings.organization'),
                    name:'organization',
                    allowBlank:false
                },
                {
                    fieldLabel: __('settings.deliveryEmail'),
                    name:'deliveryEmail',
                    allowBlank:false,
                    vtype:'email'
                },
                {
                    xtype:'button',
                    text:__('settings.resetPassword'),
                    listeners: {
                        click: function(button) {
                            Ext.Ajax.request({
                                url: 'backend/reset-password',
                                method: 'POST',
                                params: {
                                    email: Receipts.GlobalState.user.email
                                },
                                success: function() {
                                    Ext.Msg.alert(__('passwordReset.successTitle'), __('passwordReset.successMessage'));

                                },
                                failure: function() {
                                    Ext.Msg.alert(__('passwordReset.failedTitle'), __('passwordReset.failedMessage'));
                                }
                            });

                        }
                    }
                }
            ],
            buttons:[{ 
                text:__('settings.update'),
                listeners: {
                    click: function(button) {
                        var form = button.up('form'),
                            win = button.up('window');
                        form.submit({
                            method:'POST',
                            waitTitle:__('settings.waitTitle'),
                            waitMsg:__('settings.waitmessage'),
                            headers: {
                                'Accept': 'application/json'
                            },
                            jsonSubmit:true,
                            success:function(e, f, action) {
                                Receipts.GlobalState.fireEvent('reloadUser');
                                win.close();
                            },
                            failure:function(form, action) {
                                Ext.Msg.alert(__('settings.failedTitle'), __('settings.failedMessage'));
                            }
                        });
                    }
                }
            }]
        }
    ]
});

        
