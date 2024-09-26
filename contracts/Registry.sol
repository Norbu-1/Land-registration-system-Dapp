// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Registry is ERC721, Ownable {
 
    address public superAdmin;
    uint public totalAdmins;

    struct Admin {
        address adminAddress;
        string city;
        string district;
        string state;
    }

    struct LandDetails {
        address owner;
        address admin;
        uint256 propertyId;
        uint surveyNumber;
        uint index;
        bool registered;
        uint marketValue;
        bool markAvailable;
        mapping(uint => RequestDetails) requests;
        uint noOfRequests;
        uint sqft;
    }

    struct UserProfile {
        address userAddr;
        string fullName;
        string gender;
        string email;
        uint256 contact;
        string residentialAddr;
        uint totalIndices;
        uint requestIndices;
    }

    struct OwnerOwns {
        uint surveyNumber;
        string state;
        string district;
        string city;
    }

    struct RequestedLands {
        uint surveyNumber;
        string state;
        string district;
        string city;
    }

    struct RequestDetails {
        address whoRequested;
        uint reqIndex;
    }

    mapping(address => Admin) public admins;
    mapping(address => mapping(uint => OwnerOwns)) public ownerMapsProperty;
    mapping(address => mapping(uint => RequestedLands)) public requestedLands;
    mapping(string => mapping(string => mapping(string => mapping(uint => LandDetails)))) public landDetailsMap;
    mapping(address => UserProfile) public userProfile;

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) Ownable(msg.sender) {
        superAdmin = msg.sender;
    }

    modifier onlyAdmin() {
        require(admins[msg.sender].adminAddress != address(0), "Only admin can register land");
        _;
    }

    function addAdmin(address _adminAddr, string memory _state, string memory _district, string memory _city) external onlyOwner {
        require(admins[_adminAddr].adminAddress == address(0), "Admin already exists");

        Admin storage newAdmin = admins[_adminAddr];
        totalAdmins++;

        newAdmin.adminAddress = _adminAddr;
        newAdmin.city = _city;
        newAdmin.district = _district;
        newAdmin.state = _state;
    }

    function isAdmin() external view returns (bool) {
        return admins[msg.sender].adminAddress != address(0);
    }

    function registerLand(
        string memory _state,
        string memory _district,
        string memory _city,
        uint256 _propertyId,
        uint _surveyNo,
        address _owner,
        uint _marketValue,
        uint _sqft
    ) external onlyAdmin {
        require(
            keccak256(abi.encodePacked(admins[msg.sender].state)) == keccak256(abi.encodePacked(_state)) &&
            keccak256(abi.encodePacked(admins[msg.sender].district)) == keccak256(abi.encodePacked(_district)) &&
            keccak256(abi.encodePacked(admins[msg.sender].city)) == keccak256(abi.encodePacked(_city)),
            "Admin can only register land of the same city."
        );

        require(!landDetailsMap[_state][_district][_city][_surveyNo].registered, "Survey Number already registered!");

        LandDetails storage newLandRegistry = landDetailsMap[_state][_district][_city][_surveyNo];
        OwnerOwns storage newOwnerOwns = ownerMapsProperty[_owner][userProfile[_owner].totalIndices];

        newLandRegistry.owner = _owner;
        newLandRegistry.admin = msg.sender;
        newLandRegistry.propertyId = _propertyId;
        newLandRegistry.surveyNumber = _surveyNo;
        newLandRegistry.index = userProfile[_owner].totalIndices;
        newLandRegistry.registered = true;
        newLandRegistry.marketValue = _marketValue;
        newLandRegistry.markAvailable = false;
        newLandRegistry.sqft = _sqft;

        newOwnerOwns.surveyNumber = _surveyNo;
        newOwnerOwns.state = _state;
        newOwnerOwns.district = _district;
        newOwnerOwns.city = _city;

        userProfile[_owner].totalIndices++;

        _mint(_owner, _propertyId);
    }

    function setUserProfile(string memory _fullName, string memory _gender, string memory _email, uint256 _contact, string memory _residentialAddr) external {
        UserProfile storage newUserProfile = userProfile[msg.sender];

        newUserProfile.fullName = _fullName;
        newUserProfile.gender = _gender;
        newUserProfile.email = _email;
        newUserProfile.contact = _contact;
        newUserProfile.residentialAddr = _residentialAddr;
    }

    function markMyPropertyAvailable(uint indexNo) external {
        require(ownerMapsProperty[msg.sender][indexNo].surveyNumber != 0, "Property does not exist");

        string memory state = ownerMapsProperty[msg.sender][indexNo].state;
        string memory district = ownerMapsProperty[msg.sender][indexNo].district;
        string memory city = ownerMapsProperty[msg.sender][indexNo].city;
        uint surveyNumber = ownerMapsProperty[msg.sender][indexNo].surveyNumber;

        require(!landDetailsMap[state][district][city][surveyNumber].markAvailable, "Property already marked available");

        landDetailsMap[state][district][city][surveyNumber].markAvailable = true;
    }

    function RequestForBuy(string memory _state, string memory _district, string memory _city, uint _surveyNo) external {
        LandDetails storage thisLandDetail = landDetailsMap[_state][_district][_city][_surveyNo];
        require(thisLandDetail.markAvailable, "This property is NOT marked for sale!");

        uint req_serialNum = thisLandDetail.noOfRequests;
        thisLandDetail.requests[req_serialNum].whoRequested = msg.sender;
        thisLandDetail.requests[req_serialNum].reqIndex = userProfile[msg.sender].requestIndices;
        thisLandDetail.noOfRequests++;

        RequestedLands storage newRequestedLands = requestedLands[msg.sender][userProfile[msg.sender].requestIndices];
        newRequestedLands.surveyNumber = _surveyNo;
        newRequestedLands.state = _state;
        newRequestedLands.district = _district;
        newRequestedLands.city = _city;

        userProfile[msg.sender].requestIndices++;
    }

    function AcceptRequest(uint _index, uint _reqNo) external {
        require(ownerMapsProperty[msg.sender][_index].surveyNumber != 0, "Property does not exist");

        uint _surveyNo = ownerMapsProperty[msg.sender][_index].surveyNumber;
        string memory _state = ownerMapsProperty[msg.sender][_index].state;
        string memory _district = ownerMapsProperty[msg.sender][_index].district;
        string memory _city = ownerMapsProperty[msg.sender][_index].city;

        LandDetails storage landDetail = landDetailsMap[_state][_district][_city][_surveyNo];
        address newOwner = landDetail.requests[_reqNo].whoRequested;

        require(newOwner != address(0), "Invalid request");

        for (uint i = 0; i < landDetail.noOfRequests; i++) {
            address del_reqAddr = landDetail.requests[i].whoRequested;
            if (del_reqAddr != address(0)) {
                uint del_index = landDetail.requests[i].reqIndex;
                for (uint j = del_index; j < userProfile[del_reqAddr].requestIndices - 1; j++) {
                    requestedLands[del_reqAddr][j] = requestedLands[del_reqAddr][j + 1];
                }
                delete requestedLands[del_reqAddr][userProfile[del_reqAddr].requestIndices - 1];
                userProfile[del_reqAddr].requestIndices--;
            }
        }
        landDetail.noOfRequests = 0;

        ownerMapsProperty[newOwner][userProfile[newOwner].totalIndices] = ownerMapsProperty[msg.sender][_index];
        userProfile[newOwner].totalIndices++;

        delete ownerMapsProperty[msg.sender][_index];
        for (uint i = _index; i < userProfile[msg.sender].totalIndices - 1; i++) {
            ownerMapsProperty[msg.sender][i] = ownerMapsProperty[msg.sender][i + 1];
        }
        delete ownerMapsProperty[msg.sender][userProfile[msg.sender].totalIndices - 1];
        userProfile[msg.sender].totalIndices--;

        landDetail.owner = newOwner;
        landDetail.markAvailable = false;

        _transfer(msg.sender, newOwner, landDetail.propertyId);
    }

    function getLandDetails(string memory _state, string memory _district, string memory _city, uint _surveyNo) external view returns (address, uint256, uint, uint, uint) {
        LandDetails storage land = landDetailsMap[_state][_district][_city][_surveyNo];
        return (land.owner, land.propertyId, land.index, land.marketValue, land.sqft);
    }

    function getRequestCnt_propId(string memory _state, string memory _district, string memory _city, uint _surveyNo) external view returns (uint, uint256) {
        LandDetails storage land = landDetailsMap[_state][_district][_city][_surveyNo];
        return (land.noOfRequests, land.propertyId);
    }

    function getRequesterDetail(string memory _state, string memory _district, string memory _city, uint _surveyNo, uint _reqIndex) external view returns (address) {
        LandDetails storage land = landDetailsMap[_state][_district][_city][_surveyNo];
        return (land.requests[_reqIndex].whoRequested);
    }

    function isAvailable(string memory _state, string memory _district, string memory _city, uint _surveyNo) external view returns (bool) {
        return landDetailsMap[_state][_district][_city][_surveyNo].markAvailable;
    }

    function getOwnerOwns(uint index) external view returns (string memory, string memory, string memory, uint) {
        OwnerOwns storage ownerOwns = ownerMapsProperty[msg.sender][index];
        return (ownerOwns.state, ownerOwns.district, ownerOwns.city, ownerOwns.surveyNumber);
    }

    function getRequestedLands(uint index) external view returns (string memory, string memory, string memory, uint) {
        RequestedLands storage request = requestedLands[msg.sender][index];
        return (request.state, request.district, request.city, request.surveyNumber);
    }

    function getUserProfile() external view returns (string memory, string memory, string memory, uint256, string memory) {
        UserProfile storage user = userProfile[msg.sender];
        return (user.fullName, user.gender, user.email, user.contact, user.residentialAddr);
    }

    function getIndices() external view returns (uint, uint) {
        UserProfile storage user = userProfile[msg.sender];
        return (user.totalIndices, user.requestIndices);
    }

    function didIRequested(string memory _state, string memory _district, string memory _city, uint _surveyNo) external view returns (bool) {
        LandDetails storage landDetail = landDetailsMap[_state][_district][_city][_surveyNo];
        uint noOfRequests = landDetail.noOfRequests;

        for (uint i = 0; i < noOfRequests; i++) {
            if (landDetail.requests[i].whoRequested == msg.sender) {
                return true;
            }
        }
        return false;
    }
}
