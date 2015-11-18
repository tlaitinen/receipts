Ext.define('Receipts.view.RequestPasswordReset',{
    extend: 'Ext.Panel',
    alias: 'widget.requestPasswordReset',
    layout: 'fit',
    items: [
        { 
            xtype: 'form',
            url: 'backend/reset-password',
            errorReader: 'customreader',
            defaultType:'textfield',
            bodyPadding:10,
            items: [
                {
                    fieldLabel: __('requestPasswordReset.email'),
                    name: 'email',
                    allowBlank:false,
                    vtype:'email'
                }
            ],
            buttons:[{ 
                text:__('requestPasswordReset.submit'),
                listeners: {
                    click: function(button) {
                        button.up('form').submit({
                            success: function() {
                                Ext.Msg.alert(__('requestPasswordReset.successTitle'), __('requestPasswordReset.successMessage'));
                                
                                button.up('window').close();
                            },
                            failure: function() {
                                Ext.Msg.alert(__('requestPasswordReset.failedTitle'), __('requestPasswordReset.failedMessage'));
                            }
                        });
                    }
                }
            }]
        }
    ]
});
