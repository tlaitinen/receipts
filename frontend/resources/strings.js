function __(k,d) {
    var strings = {
        'locale' : 'fi',
        'receipts.unclassified' : 'Lajittelemattomat',
        'site.title' : 'Paprut.fi palvelun avulla lähetät näpsäkästi kuukausittaisen kirjanpitoaineistosi sähköisesti kirjanpitäjällesi.',
        'receipttransferform.title' : 'Siirto toiselle kirjanpitojaksolle',
        'receipttransferform.yes' : 'Siirrä valitut tositteet',
        'receipttransferform.no' : 'Peruuta',
        'receipttransferform.errortitle' : 'Virhe',
        'receipttransferform.errormessage' : 'Tositteiden siirto toiselle kirjanpitojaksolle ei onnistunut.',
        'noprocessperiod.title' : 'Kirjanpitojakso puuttuu',
        'noprocessperiod.message' : 'Kirjanpitojakso puuttuu. Uusi kirjanpitojakso avataan seuraavan kuun alussa.',
        'confirmsend.title' : 'Kirjanpitoaineiston lähettäminen',
        'confirmsend.message' : 'Lähetetäänkö kirjanpitojakson tositteet käsiteltäväksi?`',
        'receipts.preview' : 'Tositteen kuva',
        'preview.notAvailable' : 'Esikatselu ei ole saatavilla. Voit ladata tiedoston klikkaamalla linkkiä.',
        'saveError.title': 'Tietojen tallentaminen epäonnistui',
        'saveError.message': 'Tietojen tallentaminen epäonnistui: ',
        'userpasswordform.title' : 'Käyttäjän salasanan muuttaminen',
        'ok' : 'OK',
        'cancel' : 'Peruuta',
        'passwordMinLength' : 'Salasanan tulee olla vähintään kuusi merkkiä pitkä',
        'validationError.title' : 'Virheellisiä tietoja',
        'validationError.message' : 'Lomakkeella on virheellisiä tietoja.',
        'validationError.password' : 'Salasanat eivät täsmää.',
        'login.title' : 'Kirjautuminen paprut.fi-sivuille',
        'login.waittitle' : 'Kirjautuminen käynnissä',
        'login.waitmessage' : 'Lähetetään tietoja',
        'login.failedtitle' : 'Virhe',
        'login.failedmessage' : 'Kirjautuminen epäonnistui',
        'username' : 'Käyttäjänimi',
        'password' : 'Salasana',
        'login.login' : 'Kirjaudu sisään',
        'maintab.signout' : 'Kirjaudu ulos',
        'receipts' : 'Tositteet',
        'instructions' : 'Ohje',
        'users' : 'Käyttäjät',
        'usersgrid.title' : 'Käyttäjät',
        'usersgrid.emptyPaging' : 'Ei käyttäjiä',
        'usersgrid.new' : 'Uusi käyttäjä',
        'usersgrid.remove' : 'Poista valitut käyttäjät',
        'usergroupscombo.emptyText' : 'Käyttäjäryhmä',
        'usergroupsgrid.title' : 'Käyttäjäryhmät',
        'usergroupsgrid.emptyPaging' : 'Ei käyttäjäryhmiä',
        'usergroupsgrid.new' : 'Uusi ryhmä',
        'usergroupsgrid.remove' : 'Poista valitut ryhmät',
        'userform.title' : 'Käyttäjän tietojen muokkaaminen',
        'userform.defaultUserGroupId' : 'Oletusryhmä',
        'userform.setUserPassword' : 'Vaihda salasana',
        'search' : 'Haku',
        'name' : 'Nimi',
        'firstName' : 'Etunimi',
        'lastName' : 'Sukunimi',
        'email' : 'Sähköpostiosoite',
        'timeZone' : 'Aikavyöhyke',
        'passwordAgain' : 'Salasana uudestaan',
        'userName' : 'Käyttäjä',
        'userGroupName' : 'Käyttäjäryhmä',
        'contentType' : 'Tiedostotyyppi',
        'insertionTime' : 'Ladattu',
        'save' : 'Tallenna muutokset',
        'close' : 'Sulje',
        'saveandclose' : 'Tallenna muutokset ja sulje',
        'closewithoutsaving' : 'Sulje tallentamatta muutoksia',
        'usergroupitemsgrid.title' : 'Oikeudet käyttäjäryhmissä',
        'usergroupitemsgrid.emptyPaging' : 'Ei oikeuksia käyttäjäryhmissä',
        'usergroupitemsgrid.remove' : 'Poista valitut käyttäjäoikeudet',
        'users.addReadPerm' : 'Lisää lukuoikeus valituille käyttäjille valittuihin ryhmiin',
        'users.addWritePerm' : 'Lisää luku- ja kirjoitusoikeus valituille käyttäjille valittuihin ryhmiin',
        'receiptsgrid.title' : 'Tositteet',
        'receiptsgrid.name' : 'Selite',
        'receiptsgrid.emptyPaging' : 'Ei tositteita',
        'receiptsgrid.remove' : 'Poista valitut',
        'receiptsgrid.transfer' : 'Siirrä toiselle kirjanpitojaksolle',
        'receiptsgrid.send' : 'Lähetä kirjanpitojakson tositteet',
        'receiptsgrid.processed' : 'Lähetetty',
        'unclassifiedreceiptsgrid.title' : 'receiptsgrid.title',
        'unclassifiedreceiptsgrid.name' : 'receiptsgrid.name',
        'unclassifiedreceiptsgrid.emptyPaging' : 'receiptsgrid.emptyPaging',
        'unclassifiedreceiptsgrid.processPeriodId' : 'Siirrä kirjanpitojaksolle',
        'unclassifiedreceiptsgrid.remove' : 'receiptsgrid.remove',
        'processperiodscombo.emptyText' : 'Kirjanpitojakso',
        'receiptsgrid.fileName' : 'Tiedosto',
        'amount' : 'Summa',
        'insertionTime' : 'Lisätty',
        'upload.title' : 'Tiedostojen lataus',
        'upload.button' : 'Lisää tositteita tiputtamalla tiedostoja tähän.',
        'upload.uploading' : 'Ladataan...',
        'usergroupform.title' : 'Käyttäjäryhmän tietojen muokkaaminen',
        'usergroupform.createPeriods' : 'Luotavien kirjanpitokuukausien lkm.'

    };
    var parts = k.split('.');
    if (k in strings) {
        while (k in strings) {
            var pk = k;
            k = strings[k];
            if (pk == k)
                break;
        }
        return k;
    } else if (parts[parts.length - 1] in strings) {
        k = parts[parts.length - 1];
        while (k in strings) {
            var pk = k;
            k = strings[k];
            if (pk == k)
                break;
        }
        return k;
    } else if (d) {
        return __(d);
    } else {
        return k;
    }
};
