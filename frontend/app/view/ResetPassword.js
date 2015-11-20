Ext.define('Receipts.view.ResetPassword',{
    extend: 'Ext.Panel',
    alias: 'widget.resetPassword',
    layout: 'fit',
    items: [
        { 
            xtype: 'form',
            errorReader: 'customreader',
            defaultType:'textfield',
            bodyPadding:10,
            items: [
                {
                    fieldLabel: __('login.password'),
                    name: 'password',
                    allowBlank:false,
                    inputType:'password',
                    minLength:8
                },
                {
                    fieldLabel : __('login.passwordAgain'),
                    name : 'passwordAgain',
                    inputType:'password',
                    enableKeyEvents:true,
                    allowBlank:false,
                }
            ],
            buttons:[{ 
                text:__('login.resetPassword'),
                name:'resetPassword',
                disabled:true
            }]
        }
    ]
});
