import ballerina/http;
import ballerina/sql;
import ballerinax/mysql;

final mysql:Client dbClient = check new (dbHost, dbUser, dbPass, db, dbPort);

# A service representing a network-accessible API
# bound to port `9090`.
service /donor on new http:Listener(9090) {

    # A resource for reading all aidPackages
    # + return - List of aidPackages
    resource function get aidpackages() returns AidPackage[]|error {
        string status = "Draft";
        AidPackage[] aidPackages = [];
        stream<AidPackage, error?> resultStream = dbClient->query(`SELECT PACKAGEID, NAME, DESCRIPTION, STATUS 
                                                                       FROM AID_PACKAGE
                                                                       WHERE STATUS!=${status};`);
        check from AidPackage aidPackage in resultStream
            do {
                aidPackages.push(aidPackage);
            };
        check resultStream.close();
        foreach AidPackage aidPackage in aidPackages {
            stream<AidPackageItem, error?> resultItemStream = dbClient->query(`SELECT PACKAGEITEMID, PACKAGEID, QUOTATIONID, 
                                                                                NEEDID, QUANTITY, TOTALAMOUNT 
                                                                                FROM AID_PACKAGE_ITEM
                                                                                WHERE PACKAGEID=${aidPackage.packageID};`);
            AidPackageItem[] aidPackageItems = [];
            check from AidPackageItem aidPackageItem in resultItemStream
                do {
                    aidPackageItems.push(aidPackageItem);
                };
            check resultItemStream.close();
            aidPackage.aidPackageItems = aidPackageItems;
        }
        return aidPackages;
    }

    # A resource for reading donor pledged aidPackages
    # + return - List of aidPackages 
    resource function get [int donorID]/aidpackages() returns AidPackage[]|error {
        string status = "Draft";
        AidPackage[] aidPackages = [];
        stream<AidPackage, error?> resultStream = dbClient->query(`SELECT AID_PACKAGE.PACKAGEID, NAME, DESCRIPTION, 
                                                                    AID_PACKAGE.STATUS 
                                                                    FROM AID_PACKAGE INNER JOIN PLEDGE 
                                                                        ON AID_PACKAGE.PACKAGEID = PLEDGE.PACKAGEID 
                                                                    WHERE AID_PACKAGE.STATUS!=${status} AND DONORID=${donorID}`);
        check from AidPackage aidPackage in resultStream
            do {
                aidPackages.push(aidPackage);
            };
        check resultStream.close();
        foreach AidPackage aidPackage in aidPackages {
            stream<AidPackageItem, error?> resultItemStream = dbClient->query(`SELECT PACKAGEITEMID, PACKAGEID, QUOTATIONID, 
                                                                                   NEEDID, QUANTITY, TOTALAMOUNT 
                                                                                   FROM AID_PACKAGE_ITEM
                                                                                   WHERE PACKAGEID=${aidPackage.packageID};`);
            AidPackageItem[] aidPackageItems = [];
            check from AidPackageItem aidPackageItem in resultItemStream
                do {
                    aidPackageItems.push(aidPackageItem);
                };
            check resultItemStream.close();
            aidPackage.aidPackageItems = aidPackageItems;
        }
        return aidPackages;
    }

    # A resource for fetching an aidPackage not in Draft status
    # + return - An aidPackage
    resource function get [int donorID]/aidpackage/[int AidPackageID]() returns AidPackage?|error {
        string status = "Draft";
        AidPackage? aidPackage = ();
        aidPackage = check dbClient->queryRow(`SELECT PACKAGEID, NAME, DESCRIPTION, STATUS FROM AID_PACKAGE  
                                               WHERE PACKAGEID=${AidPackageID};`);
        stream<AidPackageItem, error?> resultItemStream = dbClient->query(`SELECT PACKAGEITEMID, PACKAGEID, QUOTATIONID, 
                                               NEEDID, QUANTITY, TOTALAMOUNT FROM AID_PACKAGE_ITEM 
                                               WHERE PACKAGEID=${AidPackageID} WHERE STATUS!=${status};`);
        if aidPackage is AidPackage {
            AidPackageItem[] aidPackageItems = [];
            check from AidPackageItem aidPackageItem in resultItemStream
                do {
                    aidPackageItems.push(aidPackageItem);
                };
            check resultItemStream.close();
            aidPackage.aidPackageItems = aidPackageItems;
        }
        return aidPackage;
    }

    # A resource for doind an pledge
    # + return - An aidPackage
    resource function post [int donorID]/aidpackage/[int AidPackageID]/pledge(@http:Payload Pledge pledge) returns Pledge|error {
        pledge.donorID = donorID;
        pledge.packageID = AidPackageID;
        pledge.status = "Pledged";
        sql:ExecutionResult result = check dbClient->execute(`INSERT INTO PLEDGE (PACKAGEID,DONORID,STATUS) 
                                    VALUES (${pledge.packageID},${pledge.donorID},${pledge.status});`);
        var lastInsertedID = result.lastInsertId;
        if lastInsertedID is int {
            pledge.pledgeID = lastInsertedID;
        } else {
            return error("Unable to obtain last insert ID");
        }
        return pledge;
    }

    # A resource for fetching all comments of an aidPackage
    # + return - list of aidPackageUpdateComments
    resource function get aidpackage/[int AidPackageID]/updatecomments() returns AidPackageUpdate[]|error {
        AidPackageUpdate[] aidPackageUpdates = [];
        mysql:Client dbClient = check new (dbHost, dbUser, dbPass, db, dbPort);

        stream<AidPackageUpdate, error?> resultStream = dbClient->query(`SELECT PACKAGEID, PACKAGEUPDATEID, UPDATECOMMENT,DATE_FORMAT(DATETIME, '%Y-%m-%d %T') FROM AID_PACKAGAE_UPDATE WHERE PACKAGEID=${AidPackageID};`);
        check from AidPackageUpdate aidPackageUpdate in resultStream
            do {
                aidPackageUpdates.push(aidPackageUpdate);
            };
        check resultStream.close();
        return aidPackageUpdates;
    }
}

