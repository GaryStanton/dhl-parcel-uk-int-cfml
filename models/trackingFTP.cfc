/**
 * Name: DHL Parcel UK International Tracking Event FTP Manager
 * Author: Gary Stanton (@SimianE)
 * Description: Handles the use of DHL Parcel UK International 'tracking data' files stored on the DHL SFTP server. 
 * You will need to contact the DHL Customer Integrations team to have them set up access for your account.
 */
component singleton accessors="true" {

	property name="sftpServer"      type="string" default="sftp3.dhl.com";
	property name="sftpPort"      	type="numeric" default="4222";
	property name="sftpUsername"    type="string";
	property name="sftpPassword"    type="string";
	property name="filePath" 		type="string" default="#GetDirectoryFromPath(GetCurrentTemplatePath())#../store/";
	property name="connectionName"  type="string" default="DHLConnection_#CreateUUID()#";
	property name="connectionOpen"  type="boolean" default="false";

	/**
	 * Constructor
	 * 
	 * @sftpServer 		The location of the DHL SFTP server. Defaults to sftp3.dhl.com
	 * @sftpPort    	The port to use when connecting to the SFTP server. Defaults to 4222
	 * @sftpUsername    Your SFTP username, provided by DHL UK International
	 * @sftpPassword    Your SFTP password, provided by DHL UK International
	 * @filePath    	The filesystem location to use when processing files. Defaults to /store.
	 */
	public trackingFTP function init(
			string sftpServer
		,	numeric sftpPort
		,   required string sftpUsername
		,   required string sftpPassword
		,   string filePath
	){  
		if (structKeyExists(Arguments, 'sftpServer')) {
			setSftpServer(Arguments.sftpServer);
		}
		if (structKeyExists(Arguments, 'sftpPort')) {
			setSftpPort(Arguments.sftpPort);
		}
		setSftpUsername(Arguments.sftpUsername);
		setSftpPassword(Arguments.sftpPassword);

		// Create file store
		if (!directoryExists(getFilePath())) {
			DirectoryCreate(getFilePath());
		}

		return this;
	}


	private function openConnection() {
		// Open FTP connection
		cfftp(
				action = "open"
			,   connection = getConnectionName()
			,   username = getSftpUsername()
			,   password = getSftpPassword()
			,   server = getSftpServer()
			,   port = getSftpPort()
			,   secure = true
			,   stoponerror = true
		);

		setConnectionOpen(cfftp.succeeded);

		return cfftp;
	}


	private function closeConnection() {
		cfftp(
			action = "close"
		,   connection = getConnectionName()
		,   stoponerror = true
		);

		setConnectionOpen(cfftp.succeeded);

		return cfftp;
	}


	private function getFileListCommand() {
		cfftp(
			action = "listdir"
		,   connection = getConnectionName()
		,   directory="out/work/"
		,   name = "Local.DHLFiles"
		,   stoponerror = true
		);

		// Sort files
		Local.DHLFiles = queryExecute("
			SELECT * FROM Local.DHLFiles
			WHERE isdirectory = 'false'
			ORDER BY LastModified ASC
		", {} , {dbtype="query"});

		return Local.DHLFiles;
	}


	private function retrieveFileCommand(
			required string fileName
		,	boolean removeFromServer = false
	) {

		cfftp(
			action = "getFile"
		,   connection = getConnectionName()
		,   remoteFile = 'out/work/' & Arguments.fileName
		,	localFile = getFilePath() & Arguments.fileName
		,   stoponerror = true
		,	failIfExists = false
		);

		if (Arguments.removeFromServer) {
			deleteFileCommand(Arguments.fileName);
		}

		return cfftp;
	}


	private function deleteFileCommand(
			required string fileName
	) {
		cfftp(
			action = "remove"
		,   connection = getConnectionName()
		,   item = 'out/work/' & Arguments.fileName
		,   stoponerror = true
		);

		return cfftp;
	}

	/**
	 * Returns a query object of files on the SFTP server
	 */
	public function getFileList() {
		openConnection();
		Local.fileList = getFileListCommand();
		closeConnection();

		return Local.fileList;
	}


	/**
	 * Delete a file from the FTP server
	 */
	public function deleteFile(
		required string FileName
	) {
		openConnection();
		Local.result = deleteFileCommand(Arguments.FileName);
		closeConnection();

		return Local.result;
	}



	/**
	 * Filter a file list query object by name and/or date
	 *
	 * @fileNames 			Optionally provide a specific filename or list of filenames
	 * @dateRange			Optionally provide a comma separated (inclusive) date range (yyyy-mm-dd,yyyy-mm-dd) to filter files. Where a single date is passed, all files from that date will be included.
	 *
	 * @return     			Query object containing tracking event data
	 */
	public function filterFileList(
			query fileList
		,	string fileNames
		,	string dateRange
		,	numeric maxFiles = 0
	) {
		
		var fileList = StructKeyExists(Arguments, 'fileList') ? Arguments.fileList : getFileList();

		// If we're looking at a local file list, we'll have 'dateLastModified' instead of 'lastModified'
		Local.modifiedColumnName = StructKeyExists(fileList, 'dateLastModified') ? 'dateLastModified' : 'lastModified';

		// Filter query
		Local.SQL = "
			SELECT * 
			FROM fileList
			WHERE 1 = 1
		";

		Local.Params = {};

		if (structKeyExists(Arguments, 'fileNames')) {
			Local.SQL &= "
				AND 	name IN (:filenames)
			";

			Local.Params.filenames = {value = Arguments.fileNames, list = true};
		}

		if (structKeyExists(Arguments, 'dateRange')) {
			Local.SQL &= "
				AND 	#Local.modifiedColumnName# >= :DateFrom
			";

			Local.Params.DateFrom = {value = DateFormat(ListFirst(Arguments.dateRange), 'yyyy-mm-dd')};
		}

		if (structKeyExists(Arguments, 'dateRange') && listLen(Arguments.DateRange) == 2) {
			Local.SQL &= "
				AND 	#Local.modifiedColumnName# < :DateTo
			";

			Local.Params.DateTo = {value = DateAdd('d', 1, DateFormat(ListLast(Arguments.dateRange), 'yyyy-mm-dd'))};
		}

		Local.fileList = queryExecute(Local.SQL, Local.params , {dbtype="query", maxrows=Arguments.MaxFiles > 0 ? Arguments.MaxFiles : 9999999});

		return Local.fileList;
	}



	/**
	 * Retrieve files from the DHL UK SFTP server and return a query object containing their data
	 *
	 * @fileNames 			Optionally provide a specific filename or list of filenames to process
	 * @dateRange			Optionally provide a comma separated (inclusive) date range (yyyy-mm-dd,yyyy-mm-dd) to filter files to process. Where a single date is passed, all files from that date will be included.
	 * @removeFromServer  	When true, processed files are removed from the remote server
	 *
	 * @return     			Query object containing tracking event data
	 */
	public function processRemoteFiles(
			string fileNames
		,	string dateRange
		,	boolean removeFromServer = false
		,	numeric maxFiles = 0
	) {

		openConnection();

		Local.fileList = filterFileList(
			fileList 			= getFileListCommand()
		,	ArgumentCollection 	= Arguments
		);		

		// Array to store local filenames
		Local.localFiles = [];

		// Loop through the files and process
		for (Local.thisFile in Local.fileList) {
			Local.retrieveFile = retrieveFileCommand(Local.thisFile.name, Arguments.removeFromServer);

			if (Local.retrieveFile.succeeded) {
				Local.localFiles.append(Local.thisFile.name);
			}
		}

		closeConnection();

		// Process local files
		if (Local.localFiles.len()) {
			Local.queryObject = processLocalFiles(arrayToList(Local.LocalFiles))

			return Local.queryObject;
		}
		else {
			return 'No matching files found.';
		}
	}


	public function processLocalFiles(
			string fileNames
		,	string dateRange
		,	numeric maxFiles = 0
	) {
		// Get file query object
		Local.fileList = filterFileList(
			fileList 			= directoryList(getFilePath(), false, 'query')
		,	ArgumentCollection 	= Arguments
		);

		Local.colList = 'Line_Type,Unique_ID,Status_code,Status_description,Weight,Weight_qualifier,Number_of_packages,Shipper_reference,Air_waybill_number,Delivery_date,Delivery_time,Pickup_date,Destination,Origin,Transshipment_point,Shipment_Product_Code,Shipper_account_number,Payer_account_number,Shipper_name,Shipper_contact,Shipper_address_line_1,Shipper_address_line_2,Shipper_address_line_3,Shipper_city,Shipper_zip_code,Shipper_country,Shipper_telephone,Consignee_name,Consignee_contact,Consignee_address_line 1,Consignee_address_line 2,Consignee_address_line 3,Consignee_city,Consignee_zip_code,Consignee_country,Consignee_telephone,Signatory,NU,';

		Local.conversion = new conversion();
		Local.queryObject = queryNew(Local.colList);
		Local.queryObject.addColumn('Filename');


		for (Local.thisFile in Local.fileList) {
			Local.data = Local.conversion.CSVToQuery(
				CSV = fileRead(getFilePath() & Local.thisFile.name)
			, 	Delimiter = '|'
			, 	HeaderRow = 0
			);

			Local.data = Local.conversion.queryRenameColumns(Local.data, ListToArray(Local.data.columnList), ListToArray(Local.colList)); // Rename columns, as the CSVToQuery function returns numbered columns
			for (Local.thisRow in Local.data) {
				if (Local.thisRow.Line_Type == 'D') {
					Local.queryObject.addRow(Local.thisRow);
					Local.queryObject.fileName[Local.queryObject.RecordCount] = Local.thisFile.name;
				}
			}
		}

		return Local.queryObject;
	}


	private function processData(filename, data, cols, colWidths, queryObject) {
		Local.conversion = new conversion();
		Local.data = Local.conversion.fixedWidthToQuery(Arguments.cols, Arguments.colWidths, Arguments.data);

		for (Local.thisRow in Local.data) {
			Arguments.queryObject.addRow(Local.thisRow);
			Arguments.queryObject.fileName[Arguments.queryObject.RecordCount] = Arguments.filename;
		}

		return Arguments.queryObject
	}
}