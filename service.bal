import ballerina/http;
import ballerina/sql;
import ballerinax/mysql;

//Uncomment and add listener when ballerina/http module 2.3.0 is available at choreo with next update
//listener http:Listener interceptorListener = new http:Listener(servicePort, config = {
//  interceptors: [responseErrorInterceptor] 
//});

# A service representing a network-accessible API
# bound to port `9090`.
service /donor on new http:Listener(servicePort) {

    # A resource for reading all aidPackages
    # + return - List of aidPackages
    resource function get aidpackages() returns AidPackage[]|error {
        string status = "Draft";
        AidPackage[] aidPackages = [];
        mysql:Client dbClient = check new (dbHost, dbUser, dbPass, db, dbPort);

        stream<AidPackage, error?> resultStream = dbClient->query(`SELECT PACKAGEID, NAME, DESCRIPTION, STATUS 
                                                                       FROM AID_PACKAGE
                                                                       WHERE STATUS!=${status};`);
        check from AidPackage aidPackage in resultStream
            do {
                aidPackage.aidPackageItems = [];
                aidPackages.push(aidPackage);
            };
        foreach AidPackage aidPackage in aidPackages {
            stream<AidPackageItem, error?> resultItemStream = dbClient->query(`SELECT PACKAGEITEMID, PACKAGEID, QUOTATIONID, NEEDID, QUANTITY, TOTALAMOUNT 
                                                                                   FROM AID_PACKAGE_ITEM
                                                                                   WHERE PACKAGEID=${aidPackage.packageID};`);
            AidPackageItem[] aidPackageItems = [];
            check from AidPackageItem aidPackageItem in resultItemStream
                do {

                    aidPackageItems.push(aidPackageItem);
                };
            aidPackage.aidPackageItems = aidPackageItems;
        }
        error? e = dbClient.close();

        return aidPackages;
    }

    # A resource for reading donor pledged aidPackages
    # + return - List of aidPackages 
    resource function get [int donorID]/aidpackages() returns AidPackage[]|error {
        string status = "Draft";
        AidPackage[] aidPackages = [];
        mysql:Client dbClient = check new (dbHost, dbUser, dbPass, db, dbPort);

        stream<AidPackage, error?> resultStream = dbClient->query(`SELECT AID_PACKAGE.PACKAGEID, NAME, DESCRIPTION, AID_PACKAGE.STATUS 
                                                                       FROM AID_PACKAGE INNER JOIN PLEDGE ON AID_PACKAGE.PACKAGEID = PLEDGE.PACKAGEID 
                                                                       WHERE AID_PACKAGE.STATUS!=${status} AND DONORID=${donorID}`);
        check from AidPackage aidPackage in resultStream
            do {
                aidPackage.aidPackageItems = [];
                aidPackages.push(aidPackage);
            };
        foreach AidPackage aidPackage in aidPackages {
            stream<AidPackageItem, error?> resultItemStream = dbClient->query(`SELECT PACKAGEITEMID, PACKAGEID, QUOTATIONID, NEEDID, QUANTITY, TOTALAMOUNT 
                                                                                   FROM AID_PACKAGE_ITEM
                                                                                   WHERE PACKAGEID=${aidPackage.packageID};`);
            AidPackageItem[] aidPackageItems = [];
            check from AidPackageItem aidPackageItem in resultItemStream
                do {

                    aidPackageItems.push(aidPackageItem);
                };
            aidPackage.aidPackageItems = aidPackageItems;
        }
        error? e = dbClient.close();

        return aidPackages;
    }

    # A resource for fetching an aidPackage
    # + return - An aidPackage
    resource function get [int donorID]/aidpackage/[int AidPackageID]() returns AidPackage?|error {
        AidPackage? aidPackage = ();
        mysql:Client dbClient = check new (dbHost, dbUser, dbPass, db, dbPort);
        aidPackage = check dbClient->queryRow(`SELECT PACKAGEID, NAME, DESCRIPTION, STATUS FROM AID_PACKAGE  WHERE PACKAGEID=${AidPackageID};`);
        stream<AidPackageItem, error?> resultItemStream = dbClient->query(`SELECT PACKAGEITEMID, PACKAGEID, QUOTATIONID, NEEDID, QUANTITY, TOTALAMOUNT FROM AID_PACKAGE_ITEM WHERE PACKAGEID=${AidPackageID};`);
        if aidPackage is AidPackage {
            AidPackageItem[] aidPackageItems = [];
            check from AidPackageItem aidPackageItem in resultItemStream
                do {
                    aidPackageItems.push(aidPackageItem);
                };
            aidPackage.aidPackageItems = aidPackageItems;
        }
        error? e = dbClient.close();
        return aidPackage;
    }

    # A resource for doind an pledge
    # + return - An aidPackage
    resource function post [int donorID]/aidpackage/[int AidPackageID]/pledge(@http:Payload Pledge pledge) returns Pledge|error {
        pledge.donorID = donorID;
        pledge.packageID = AidPackageID;
        pledge.status = "Pledged";
        mysql:Client dbClient = check new (dbHost, dbUser, dbPass, db, dbPort);
        sql:ParameterizedQuery query = `INSERT INTO PLEDGE (PACKAGEID,DONORID,STATUS) 
                                                    VALUES (${pledge.packageID},${pledge.donorID},${pledge.status});`;

        sql:ExecutionResult result = check dbClient->execute(query);
        if result.lastInsertId is int {
            pledge.pledgeID = <int>result.lastInsertId;
        }
        error? e = dbClient.close();
        return pledge;
    }

    # A resource for fetching all comments of an aidPackage
    # + return - list of aidPackageUpdateComments
    resource function get aidpackage/[int AidPackageID]/updatecomments() returns AidPackageUpdate[]|error {
        AidPackageUpdate[] aidPackageUpdates = [];
        mysql:Client dbClient = check new (dbHost, dbUser, dbPass, db, dbPort);

        stream<AidPackageUpdate, error?> resultStream = dbClient->query(`SELECT PACKAGEID, PACKAGAEUPDATEID, UPDATECOMMENT, DATETIME FROM AID_PACKAGAE_UPDATE WHERE PACKAGEID=${AidPackageID};`);
        check from AidPackageUpdate aidPackageUpdate in resultStream
            do {
                aidPackageUpdates.push(aidPackageUpdate);
            };
        error? e = dbClient.close();

        return aidPackageUpdates;
    }
}

ResponseErrorInterceptor responseErrorInterceptor = new;

service class ResponseErrorInterceptor {
    //*http:ResponseErrorInterceptor; //Uncomment and enable when ballerina/http module 2.3.0 is available at choreo with next update

    remote function interceptResponseError(error err)
            returns http:InternalServerError {

        return {
            mediaType: "application/org+json",
            body: {message: err.message()}
        };
    }
}

