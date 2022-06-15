# DHL Parcel UK International CFML

DHL Parcel UK International CFML provides a wrapper for the DHL Parcel UK International Web Services.
At present, the module only includes access to the DHL sftp service for FSTAT file retrieval
Further updates may include access to other DHL Parcel UK International APIs.

## Installation
```js
box install dhl-parcel-uk-int-cfml
```

## Examples
Check out the `/examples` folder for an example implementation.

## Usage
The DHL Parcel UK International CFML wrapper currently consists of a single model, to manage connection to the DHL SFTP server to download and process FSTAT files.
The wrapper may be used standalone, or as a ColdBox module.


### Standalone
```cfc
	DHLUKINTTracking = new models.trackingFTP(
			sftpUsername 	= 'XXXXXXXX'
		,	sftpPassword 	= 'XXXXXXXX'
	);

```

### ColdBox
```cfc
DHLUKINTTracking 	= getInstance("trackingFTP@DHLParcelUKINTCFML");
```
alternatively inject it directly into your handler
```cfc
property name="DHLUKINTTracking" inject="trackingFTP@DHLParcelUKINTCFML";
```

When using with ColdBox, you'll want to insert your API authentication details into your module settings:

```cfc
DHLUKCFML = {
		sftpUsername 	= getSystemSetting("DHLUK_SFTPUSERNAME", "")
	,	sftpPassword 	= getSystemSetting("DHLUK_SFTPPASSWORD", "")
}
```

### Retrieve tracking event data
Tracking event files are uploaded to the DHL SFTP server every 20 minutes or so. The events component can be used to list, download and process these files.  

```cfc
fileList = DHLUKINTEvents.getFileList();
```

```cfc
fileContents = DHLUKINTEvents.processRemoteFiles(
		dateRange 			= '2021-01-01,2021-01-31'
	,	removeFromServer 	= false
);
```


## Author
Written by Gary Stanton.  
https://garystanton.co.uk
