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
        stream<AidPackage, error?> resultStream = dbClient->query(`SELECT PACKAGEID, NAME, DESCRIPTION, STATUS, CREATEDBY as 'createdBy' 
                                                                       FROM AID_PACKAGE
                                                                       WHERE STATUS!=${status};`);
        check from AidPackage aidPackage in resultStream
            do {
                aidPackages.push(aidPackage);
            };
        check resultStream.close();
        foreach AidPackage aidPackage in aidPackages {
            check constructAidPackageData(aidPackage);
        }
        return aidPackages;
    }

    # A resource for reading donor pledged aidPackages
    # + return - List of aidPackages 
    resource function get [string donorID]/aidpackages() returns DonorAidPackage[]|error {
        string status = "Draft";
        DonorAidPackage[] donorAidPackages = [];
        stream<DonorAidPackage, error?> resultStream = dbClient->query(`SELECT AID_PACKAGE.PACKAGEID, NAME, DESCRIPTION, 
                                                                    AID_PACKAGE.STATUS, AID_PACKAGE.CREATEDBY as 'createdBy', PLEDGE.AMOUNT 
                                                                    FROM AID_PACKAGE INNER JOIN PLEDGE 
                                                                        ON AID_PACKAGE.PACKAGEID = PLEDGE.PACKAGEID 
                                                                    WHERE AID_PACKAGE.STATUS!=${status} AND AID_PACKAGE.DONORID=${donorID}`);
        check from DonorAidPackage donorAidPackage in resultStream
            do {
                donorAidPackages.push(donorAidPackage);
            };
        check resultStream.close();
        foreach DonorAidPackage donorAidPackage in donorAidPackages {
            check constructAidPackageData(donorAidPackage);
        }
        return donorAidPackages;
    }

    # A resource for fetching an aidPackage not in Draft status
    # + return - An aidPackage
    resource function get [string donorID]/aidpackages/[int AidPackageID]() returns AidPackage?|error {
        string status = "Draft";
        AidPackage aidPackage = check dbClient->queryRow(`SELECT PACKAGEID, NAME, DESCRIPTION, STATUS, CREATEDBY as 'createdBy' FROM AID_PACKAGE  
                                               WHERE PACKAGEID=${AidPackageID} AND STATUS!=${status};`);
        check constructAidPackageData(aidPackage);
        return aidPackage;
    }

    # A resource for doind an pledge
    # + return - An aidPackage
    resource function post [string donorID]/aidpackages/[int AidPackageID]/pledge(@http:Payload Pledge pledge) returns Pledge|error {
        pledge.donorID = donorID;
        pledge.packageID = AidPackageID;
        pledge.status = "Pledged";
        sql:ExecutionResult result = check dbClient->execute(`INSERT INTO PLEDGE (PACKAGEID,DONORID,AMOUNT,STATUS) 
                                    VALUES (${pledge.packageID},${pledge.donorID},${pledge.amount},${pledge.status});`);
        var lastInsertedID = result.lastInsertId;
        if lastInsertedID is int {
            pledge.pledgeID = lastInsertedID;
        } else {
            return error("Unable to obtain last insert ID");
        }
        return pledge;
    }

    # A resource for fetching an donor pledges for aid package
    # + return - list of pledges
    resource function get [string donorID]/aidpackages/[int AidPackageID]/pledges() returns Pledge[]?|error {
        Pledge[] pledges = [];
        stream<Pledge, error?> resultStream = dbClient->query(`SELECT PLEDGEID,PACKAGEID,DONORID,AMOUNT,STATUS FROM PLEDGE  
                                               WHERE PACKAGEID=${AidPackageID} AND DONORID=${donorID};`);
        check from Pledge pledge in resultStream
            do {
                pledges.push(pledge);
            };
        check resultStream.close();
        return pledges;
    }

    # A resource for doind an pledge
    # + return - An aidPackage
    resource function put [string donorID]/aidpackages/[int AidPackageID]/pledges/[int pledgeID](@http:Payload Pledge pledge) returns Pledge|error {
        pledge.pledgeID = pledgeID;
        pledge.donorID = donorID;
        pledge.packageID = AidPackageID;
        sql:ExecutionResult _ = check dbClient->execute(`UPDATE PLEDGE SET AMOUNT = ${pledge.amount} WHERE PLEDGEID=${pledgeID};`);
        return check getPledge(pledgeID);
    }

    # A resource for fetching all comments of an aidPackage
    # + return - list of aidPackageUpdateComments
    resource function get aidpackages/[int AidPackageID]/updatecomments() returns AidPackageUpdate[]|error {
        AidPackageUpdate[] aidPackageUpdates = [];

        stream<AidPackageUpdate, error?> resultStream = dbClient->query(`SELECT PACKAGEID, PACKAGEUPDATEID, UPDATECOMMENT,UNIX_TIMESTAMP(DATETIME) as 'DATETIME'  FROM AID_PACKAGE_UPDATE WHERE PACKAGEID=${AidPackageID};`);
        check from AidPackageUpdate aidPackageUpdate in resultStream
            do {
                aidPackageUpdates.push(aidPackageUpdate);
            };
        check resultStream.close();
        return aidPackageUpdates;
    }
}

function constructAidPackageData(AidPackage|DonorAidPackage aidPackage) returns error? {
    aidPackage.aidPackageItems = [];
    stream<AidPackageItem, error?> resultItemStream = dbClient->query(`SELECT PACKAGEITEMID, PACKAGEID, QUOTATIONID,
                                                                               NEEDID, QUANTITY, TOTALAMOUNT 
                                                                               FROM AID_PACKAGE_ITEM
                                                                               WHERE PACKAGEID=${aidPackage.packageID};`);
    decimal totalAmount = 0;
    check from AidPackageItem aidPackageItem in resultItemStream
        do {
            Quotation quotation = check dbClient->queryRow(`SELECT
                                                                    QUOTATIONID, SUPPLIERID, ITEMID, BRANDNAME,
                                                                    AVAILABLEQUANTITY, PERIOD, EXPIRYDATE,
                                                                    UNITPRICE, REGULATORYINFO
                                                                    FROM QUOTATION 
                                                                    WHERE QUOTATIONID=${aidPackageItem.quotationID}`);
            quotation.supplier = check dbClient->queryRow(`SELECT
                                                                    SUPPLIERID, NAME, SHORTNAME,
                                                                    EMAIL, PHONENUMBER 
                                                                    FROM SUPPLIER 
                                                                    WHERE SUPPLIERID=${quotation.supplierID}`);
            aidPackageItem.quotation = quotation;
            aidPackageItem.totalAmount = <decimal>aidPackageItem.quantity * quotation.unitPrice;
            aidPackage.aidPackageItems.push(aidPackageItem);
            totalAmount = totalAmount + aidPackageItem.totalAmount;
        };
    check resultItemStream.close();
    aidPackage.goalAmount = totalAmount;
    decimal|error recievedAmount = dbClient->queryRow(`SELECT IFNULL(SUM(AMOUNT),0) FROM PLEDGE 
                                                        WHERE PACKAGEID = ${aidPackage.packageID};`);
    if (recievedAmount is decimal) {
        aidPackage.receivedAmount = recievedAmount;
    }
}

function getPledge(int pledgeId) returns Pledge|error {
    Pledge pledge = check dbClient->queryRow(`SELECT PLEDGEID, PACKAGEID, DONORID, AMOUNT, STATUS                                                                      FROM PLEDGE WHERE PLEDGEID=${pledgeId};`);
    return pledge;
}

