import ballerina/http;
import ballerinax/mysql;


# A service representing a network-accessible API
# bound to port `9090`.
service /donor on new http:Listener(9090) {

    # A resource for reading all aidPackages
    # + return - List of aidPackages and optionally filter by status
    resource function get AidPackages() returns json|error {
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
            check from AidPackageItem aidPackageItem in resultItemStream
                do {
                    aidPackage.aidPackageItems.push(aidPackageItem);
                };
        }
        error? e = dbClient.close();

        return {"aidPackages": aidPackages}.toJson();
    }

    # A resource for fetching an aidPackage
    # + return - An aidPackage
    resource function get AidPackage(int packageID) returns json|error {
        AidPackage? aidPackage = ();
        mysql:Client dbClient = check new (dbHost, dbUser, dbPass, db, dbPort);
        aidPackage = check dbClient->queryRow(`SELECT PACKAGEID, NAME, DESCRIPTION, STATUS FROM AID_PACKAGE  WHERE PACKAGEID=${packageID};`);
        stream<AidPackageItem, error?> resultItemStream = dbClient->query(`SELECT PACKAGEITEMID, PACKAGEID, QUOTATIONID, NEEDID, QUANTITY, TOTALAMOUNT FROM AID_PACKAGE_ITEM WHERE PACKAGEID=${packageID};`);
        if aidPackage is AidPackage {
            AidPackageItem[] aidPackageItems=[];
            check from AidPackageItem aidPackageItem in resultItemStream
            do {
                aidPackageItems.push(aidPackageItem);
            };
            aidPackage.aidPackageItems=aidPackageItems;
        }
        error? e = dbClient.close();
        return aidPackage.toJson();
    }

    // # A resource for doind an pledge
    // # + return - An aidPackage
    // resource function post AidPackage/pledge(Pledge pledge) returns json|error {
    //     mysql:Client dbClient = check new (dbHost, dbUser, dbPass, db, dbPort);
    //     sql:ParameterizedQuery query = `INSERT INTO SUPPLIER(NAME, SHORTNAME, EMAIL, PHONENUMBER)
    //                                         VALUES (${_supplier.name}, ${_supplier.shortName},
    //                                                 ${_supplier.email}, ${_supplier.phoneNumber});`;
    //         sql:ExecutionResult result = check dbClient->execute(query);
    //         if result.lastInsertId is int {
    //             _supplier.supplierID = <int> result.lastInsertId;
    //         }

    //         error? e = dbClient.close();
    //     return aidPackage.toJson();
    // }
}

