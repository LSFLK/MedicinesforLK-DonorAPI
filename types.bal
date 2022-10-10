import ballerina/time;

// Stakeholders (Main Actors)
type Supplier record {
    int supplierID = -1;
    string name;
    string shortName;
    string email;
    string phoneNumber;
};

type Beneficiary record {
    int beneficiaryID = -1;
    string name;
    string shortName;
    string email;
    string phoneNumber;
};


// Main Types
type MedicalItem record {
    int itemID = -1;
    string name;
    string 'type;
    string unit;
};

type MedicalNeedResponse record {|
    int lastUpdatedTime?;
    MedicalNeed[] medicalNeeds;
|};

type MedicalNeed record {
    int needID;
    MedicalItem item;
    time:Date period;
    string urgency;
    int neededQuantity;
    int remainingQuantity;
    Beneficiary beneficiary;
};

type Quotation record {
    int quotationID = -1;
    int supplierID;
    int itemID;
    string brandName;
    int availableQuantity;
    time:Date period;
    time:Date expiryDate;
    string regulatoryInfo;
    decimal unitPrice;
    Supplier? supplier = ();
    MedicalItem? medicalItem = ();
};

type AidPackage record {
    int packageID = -1;
    string description;
    string name;
    string status;
    decimal goalAmount?;
    decimal receivedAmount?;
    AidPackageItem[] aidPackageItems = [];
    string createdBy;
    string? thumbnail = ();
};

type AidPackageItem record {
    int packageItemID = -1;
    int packageID;
    int quotationID;
    int needID;
    int quantity;
    decimal totalAmount;
    Quotation quotation?;
};

type Pledge record {
    int pledgeID = -1;
    int packageID;
    string donorID;
    decimal amount;
    string status;
};

type AidPackageUpdate record {
    int packageUpdateId = -1;
    int packageID;
    string updateComment;
    int? dateTime;
};

//Return types
type DonorAidPackage record {|
    *AidPackage;
    decimal amount;
|};
