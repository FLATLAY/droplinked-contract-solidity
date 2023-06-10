// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.4<0.9;

contract simpleStorage {
    error NotApprovedSign(); 
    error OldPrice(); 
    
    event Mint(uint token_id, address recipient, uint amount, uint balance);
    event PulishRequest(uint token_id, uint amount, uint request_id);
    event AcceptRequest(uint request_id);
    event CancelRequest(uint request_id);
    event DisapproveRequest(uint request_id, uint amount, uint token_id);
    
    struct NFTMetadata {
        string name;
        string ipfsUrl;
        uint price;
        uint comission;
    }
    struct Request {
        uint token_id;
        uint amount;
        address producer;
        address publisher;
        bool accepted;
    }
    uint public token_cnt;
    uint public request_cnt;
    uint public total_supply;
    address public ratioVerifier;
    uint public fee;

    mapping (address => mapping(uint => uint)) public holders;
    mapping (uint => NFTMetadata) public metadatas;
    mapping (uint => Request) public requests;
    mapping (bytes32 => uint) public tokenid_by_hash;
    mapping (address => mapping (uint => bool)) public publishers_requests;
    mapping (address => mapping (uint => bool)) public producer_requests;
    
    constructor(uint _fee, address ratio_verifier){
        fee = _fee;
        ratioVerifier = ratio_verifier;
    }


    function mint(string calldata name, string calldata uri, uint _price, uint _comission, uint amount) public {
        bytes32 metadata_hash = keccak256(abi.encode(uri));
        uint token_id = tokenid_by_hash[metadata_hash];
        if (token_id == 0){
            token_id = token_cnt + 1;
            token_cnt++;
            metadatas[token_id].name = name;
            metadatas[token_id].ipfsUrl = uri;
            metadatas[token_id].price = _price;
            metadatas[token_id].comission = _comission;
            holders[msg.sender][token_id] = amount;
            tokenid_by_hash[metadata_hash] = token_id;
        }
        else{
            require(keccak256(abi.encode(metadatas[token_id].name)) == keccak256(abi.encode(name)));
            require(keccak256(abi.encode(metadatas[token_id].ipfsUrl)) == keccak256(abi.encode(uri)));
            require(metadatas[token_id].price == _price);
            require(metadatas[token_id].comission == _comission);
            holders[msg.sender][token_id] += amount;
        }
        total_supply += amount;
        emit Mint(token_id, msg.sender,amount,holders[msg.sender][token_id]);
    }
    
    function publish_request(address producer_account, uint amount, uint token_id) public{
        uint request_id = request_cnt + 1;
        request_cnt++;
        requests[request_id].token_id = token_id;
        requests[request_id].amount = amount;
        requests[request_id].producer = producer_account;
        requests[request_id].publisher = msg.sender;
        requests[request_id].accepted = false;
        publishers_requests[msg.sender][request_id] = true;
        producer_requests[producer_account][request_id] = true;
        emit PulishRequest(token_id, amount, request_id);
    }

    function approve_request(uint request_id) public {
        require(producer_requests[msg.sender][request_id] != false);
        require(holders[msg.sender][requests[request_id].token_id] >= requests[request_id].amount);
        requests[request_id].accepted = true;
        holders[msg.sender][requests[request_id].token_id] -= requests[request_id].amount;
        emit AcceptRequest(request_id);
    }

    function cancel_request(uint request_id) public {
        require(msg.sender == requests[request_cnt].publisher);
        require(requests[request_id].accepted == false);

        producer_requests[requests[request_id].producer][request_id] = false;
        publishers_requests[msg.sender][request_id] = false;
        emit CancelRequest(request_id);
    }

    function disapprove(uint request_id, uint amount) public {
        require(msg.sender == requests[request_id].producer);
        require(requests[request_id].amount >= amount);
        uint token_id = requests[request_id].token_id;
        requests[request_id].amount -= amount;
        holders[msg.sender][token_id] += amount;
        if (requests[request_id].amount == 0){
            producer_requests[msg.sender][request_id] = false;
            publishers_requests[requests[request_id].publisher][request_id] = false;
        }
    }


    function direct_buy(uint price, uint ratio, uint _blockHeight, address recipient, uint8 _v, bytes32 _r, bytes32 _s) public payable {
        if(block.number>_blockHeight+10){
             revert OldPrice();
        }
        bytes32 _hashedMessage = keccak256(abi.encodePacked(ratio,_blockHeight));
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHashMessage = keccak256(abi.encodePacked(prefix, _hashedMessage));
        address signer = ecrecover(prefixedHashMessage, _v, _r, _s);
        if (signer != ratioVerifier) {
            revert NotApprovedSign();
        }
        payable(recipient).transfer(((price*ratio) / 100) * 1000000000000000000);
    }
    
    function buy_recorded(uint token_id, uint amount) public {
        
    }

    function buy_affiliate(uint request_id, uint amount) public {
        
    }
}