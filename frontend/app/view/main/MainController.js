Ext.define('Receipts.view.main.MainController', {
    extend: 'Ext.app.ViewController',

    requires: [
        'Ext.window.MessageBox',
        'Receipts.view.main.UserSettings'
    ],

    alias: 'controller.main',
    config: {
        control: {
            '#maintab' : {
                tabchange: 'onTabChange'
            }
        },
        routes : {
            'maintab:id' : {
                action     : 'showTab',
                conditions : {
                    ':id'    : '(?:(?::){1}([%a-zA-Z0-9\-\_\s,]+))?'
                }
            },
            'preview:id' : {
                action     : 'showPreview',
                conditions : {
                    ':id'    : '(?:(?::){1}([%a-zA-Z0-9\-\_\s,]+))?'
                }
            }
        }
    },
    onLogin: function() {
        
        if (Receipts.GlobalState.user.config.usersTab == true) {
            this.lookupReference('usersTab').tab.show();
        }

        this.redirectTo('maintab:maintab-receipts');
    },

    addUserGroupItems: function(userGrid, userGroupGrid, userGroupItemsGrid, mode) {
        var users = userGrid.getSelectionModel().getSelection(),
            userGroups = userGroupGrid.getSelectionModel().getSelection(),
            userGroupItems = userGroupItemsGrid.store;
        for (var i = 0; i < users.length; i++) {
            for (var i2 = 0; i2 < userGroups.length; i2++) {
                (function(user, userGroup) {
                    userGroupItems.add(Ext.create('Receipts.model.usergroupitems',
                            {
                            userId: user.getId(),
                            userName: user.getData()['name'],
                           userGroupId : userGroup.getId(),
                            userGroupName: userGroup.getData()['name'],
                          mode: mode }));
                 })(users[i], userGroups[i2]);
            }
        }
        userGroupItems.sync();
    },
    onTabChange: function(tabPanel, newItem) {
        var id = newItem.getId();
        this.redirectTo('maintab:' + id);
    },
    showTab : function(id) {    
        Ext.WindowManager.each(function(cmp) { cmp.destroy(); });
        var tabPanel = this.lookupReference('mainTab');
        if (!id) {
            id = 0;
        }
        var child = tabPanel.getComponent(id);
        tabPanel.setActiveTab(child);
    },
    openSettings: function() {
        var win = new Ext.Window({
            id:'userSettings',
            title: __('settings.title'),
            plain:true,
            border: false,
            closable:true,
            draggable:true,
            resizable:false,
            margin: '0 0 0 0',
            items: [{xtype:'userSettings'}]
        });
        win.show();
    },
    init: function() {
        var controller = this;
        Receipts.GlobalState.on('login', function() {
            controller.onLogin();
            
        });

        this.control({
            'receiptsgrid button[name=transfer]' : {
                click: function(button) {
                    if (Ext.getCmp('receipttransferform') == undefined) {
                        var win = new Ext.Window({
                            id: "receipttransferform",
                            title: __('receipttransferform.title'),
                            width:320,
                            height:120,
                            resizable:false,
                            items : [{xtype: 'receipttransferform'}],
                            sender: button
                        });
                        win.show();
                        return win;
                    } 
                }
            },

            'receiptsgrid button[name=send]': {
                click: function(sendButton) {
                    Ext.MessageBox.confirm(__('confirmsend.title'), __('confirmsend.message'),
                        function (button) {
                        if (button == "yes") {
                            var processPeriodId = sendButton.up('grid').processPeriodId;
                            Ext.Ajax.request({
                                url: 'backend/db/processperiods/' + processPeriodId,
                                method: 'POST',
                                params: {
                                },
                                success: function() {
                                    Ext.Msg.alert(__('send.successTitle'), __('send.successMessage'));

                                },
                                failure: function() {
                                    Ext.Msg.alert(__('send.failedTitle'), __('send.failedMessage'));
                                }
                            });
                        }
                    });
                }
            },

            'panel[name=users] button[name=addReadPerm]': {
                click: function(button) {
                    var panel = button.up('panel[name=users]');
                    controller.addUserGroupItems(panel.down('usersgrid'),
                                                 panel.down('usergroupsgrid'),
                                                 panel.down('usergroupitemsgrid'),
                                                 'ReadOnly');

                }
            },
            'panel[name=users] button[name=addWritePerm]': {
                click: function(button) {
                    var panel = button.up('panel[name=users]');
                    controller.addUserGroupItems(panel.down('usersgrid'),
                                                 panel.down('usergroupsgrid'),
                                                 panel.down('usergroupitemsgrid'),
                                                 'ReadWrite');
                }
            },
            'button[name=logout]' : {
                click: function(button) {
                    $.ajax({
                        url:'backend/auth/logout',
                        type:'POST',
                        dataType:'json'
                    }).always(function() {
                        location.reload();
                    });
                }
            },
            'button[name=settings]' : {
                click: function(button) {
                    controller.openSettings();
                }
            }
        });
    }

});
