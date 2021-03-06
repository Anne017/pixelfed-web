import QtQuick 2.4
import QtQuick.Layouts 1.1
import Ubuntu.Components 1.3

Page {
    id: instancePickerPage
    anchors.fill: parent
    
    property bool searchRunning:false
    property var lastList: []
    property var updateTime: null

    Component.onCompleted: getSample ()
	
	WorkerScript {
		id:asyncProcess
		source:'../components/jslibs/FilterPods.js'
		onMessage:instanceList.writeInList (  messageObject.reply );
	}

    /* Load list of Mastodon Instances from https://instances.social
    * The Response is in format:
    * { id, name, added_at, updated_at, checked_at, uptime, up, dead, version,
    * ipv6, https_score, https_rank, obs_score, obs_rank, users, statuses,
    * connections, open_registrations, info { short_description, full_description,
    *      topic, languages[], other_languages_accepted, federates_with,
    *      prhobited_content[], categories[]}, thumbnail, active_users }
    */
    function getSample () {
		if(searchRunning) { return; }
		searchRunning = true;
        var http = new XMLHttpRequest();
		var  data = 'operationName=Platform&variables={"name":"pixelfed"}&query=query Platform($name: String!) {  platforms(name: $name) {    name    code    displayName    description    tagline    website    icon    __typename  }  nodes(platform: $name) {    id    name    version    openSignups    host    platform {      name      icon      __typename    }    countryCode    countryFlag    countryName    services {      name      __typename    }    __typename  }  statsGlobalToday(platform: $name) {    usersTotal    usersHalfYear    usersMonthly    localPosts    localComments    __typename  }  statsNodes(platform: $name) {    node {      id      __typename    }    usersTotal    usersHalfYear    usersMonthly    localPosts    localComments    __typename  }}';
		http.open("GET", "https://the-federation.info/graphql?" + data, true);
        http.setRequestHeader('Content-type', 'text/html; charset=utf-8')
        http.onreadystatechange = function() {
			searchRunning = false;
            if (http.readyState === XMLHttpRequest.DONE) {
				console.log(http.responseText);
                var response = JSON.parse(http.responseText);
				var nodes = response.data.nodes;
				lastList = nodes;
				updateTime = Date.now();
				asyncProcess.sendMessage( {searchTerm : customInstanceInput.displayText , inData : nodes });
            }
        }
        loading.running = true;
        http.send();
    }


    function search ()  {

		var searchTerm = customInstanceInput.displayText;
		//If  the  search starts with http(s) then go to the url 
		if(searchTerm.indexOf("http") == 0 ) {
			settings.instance = searchTerm
			mainStack.push (Qt.resolvedUrl("./PixelFedWebview.qml"))
			return
		}
	
		if(updateTime < Date.now()-60000) {
			loading.visible = true
			instanceList.children = ""
			getSample();
		} else {
			asyncProcess.sendMessage( {searchTerm : searchTerm ,onlyReg: onlyWithRegChkBox.checked, inData : lastList });
		}
    }



    header: PageHeader {
        id: header
        title: i18n.tr('Choose a PixelFed instance')
        StyleHints {
            foregroundColor: theme.palette.normal.backgroundText
            backgroundColor: theme.palette.normal.background
        }
        trailingActionBar {
            actions: [
            Action {
                text: i18n.tr("Info")
                iconName: "info"
                onTriggered: {
                    mainStack.push(Qt.resolvedUrl("./Information.qml"))
                }
            },
            Action {
                iconName: "search"
                onTriggered: {
                    if ( customInstanceInput.displayText == "" ) {
                        customInstanceInput.focus = true
                    } else search ()
                }
            }
            ]
        }
        extension: Row {
			anchors {
				leftMargin:units.gu(5)
			}
			CheckBox {
				id:onlyWithRegChkBox
				text: i18n.tr("Only show nodes that allow registration")
				checked: false;
				onTriggered:search();
			}
		}
    }

    ActivityIndicator {
        id: loading
        visible: true
        running: true
        anchors.centerIn: parent
    }


    TextField {
        id: customInstanceInput
        anchors.top: header.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: height
        width: parent.width - height
        placeholderText: i18n.tr("Search or enter a custom address")
		onDisplayTextChanged: if(displayText.length > 2) {search();}
        Keys.onReturnPressed: search ()
    }
    
    ScrollView {
        id: scrollView
        width: parent.width
        height: parent.height - header.height - 3*customInstanceInput.height
        anchors.top: customInstanceInput.bottom
        anchors.topMargin: customInstanceInput.height
        contentItem: Column {
            id: instanceList
            width: root.width


            // Write a list of instances to the ListView
            function writeInList ( list ) {
                instanceList.children = ""
                loading.visible = false
                list.sort(function(a,b) {return !a.usersTotal ? (!b.usersTotal ? 0 : 1) : (!b.usersTotal ? -1 : parseFloat(b.usersTotal) - parseFloat(a.usersTotal));});
                for ( var i = 0; i < list.length; i++ ) {
                    var item = Qt.createComponent("../components/InstanceItem.qml")
                    item.createObject(this, {
                        "text": list[i].name,
                        "country": list[i].countryName != null ? list[i].countryName : "",
                        "version": list[i].version != null ? list[i].version : "",
						"users": list[i].usersTotal != null ? list[i].usersTotal : "",
                        "iconSource":  list[i].thumbnail != null ? list[i].thumbnail : "../../assetspixelfed_logo.png",
						"status":  list[i].openSignups != null ? list[i].openSignups : 0,
						"rating":  list[i].score != null ? list[i].score : 0
                    })
                }
            }
        }
    }
    
    Label {
		id:noResultsLabel
		visible: !instanceList.children.length && !loading.visible
		anchors.centerIn: scrollView;
		text:customInstanceInput.length ? i18n.tr("No pods fund for search : %1").arg(customInstanceInput.displayText) :  i18n.tr("No pods returned from server");
	}

}
