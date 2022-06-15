/**
* This module wraps DHL Parcel UK International web services
**/
component {

	// Module Properties
    this.modelNamespace			= 'dhl-parcel-uk-int-cfml';
    this.cfmapping				= 'dhl-parcel-uk-int-cfml';
    this.parseParentSettings 	= true;

	/**
	 * Configure
	 */
	function configure(){

		// Skip information vars if the box.json file has been removed
		if( fileExists( modulePath & '/box.json' ) ){
			// Read in our box.json file for so we don't duplicate the information above
			var moduleInfo = deserializeJSON( fileRead( modulePath & '/box.json' ) );

			this.title 				= moduleInfo.name;
			this.author 			= moduleInfo.author;
			this.webURL 			= moduleInfo.repository.URL;
			this.description 		= moduleInfo.shortDescription;
			this.version			= moduleInfo.version;

		}

		// Settings
		settings = {
				'username' : ''
			,	'password' : ''
			,	'environment' : 'sandbox'
			,	'sftpUsername' : ''
			,	'sftpPassword' : ''
		};
	}

	function onLoad(){
		binder.map( "events@dhl-parcel-uk-int-cfml" )
			.to( "#moduleMapping#.models.events" )
			.asSingleton()
			.initWith(
					sftpUsername 	= settings.sftpUsername
				,	sftpPassword 	= settings.sftpPassword
			);
	}

}