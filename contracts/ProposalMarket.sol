// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// contract NFT is ERC721 {
//     constructor() ERC721("MyERC721", "M721") {}
// }
contract ProposalMarket {
    struct Proposal {
        address seller;
        uint numProposals;
    }

    address payable public escrow;// Ví của admin
    uint public proposalToEtherRatio; // Tỷ lệ quy đổi từ proposal sang ETH
    Proposal[] public proposals;
    uint public contractCount;

    event ProposalPurchased(uint indexed proposalId, address indexed seller, uint numProposals, uint totalPrice);

    constructor(uint _proposalToEtherRatio) {
        // Người khởi tạo hợp đồng sẽ là admin và ví này sẽ là ví nhận tiền khi mua proposal
        escrow = payable(msg.sender);
        //Khởi tạo giá trị 1 proposal = bao nhiêu eth
        proposalToEtherRatio = _proposalToEtherRatio;
        contractCount = 0;
    }

    function buyProposal(uint _numProposals) public payable  returns (uint contractId, uint numProposalsTransferred){
        uint totalPrice = _numProposals * proposalToEtherRatio*1000000000000000000;
        require(msg.value == totalPrice, "Incorrect price");
        contractId = contractCount;
        numProposalsTransferred=_numProposals;
        contractCount++;

        Proposal memory newProposal = Proposal(msg.sender, _numProposals);
        proposals.push(newProposal);

        emit ProposalPurchased(contractCount, msg.sender, _numProposals, totalPrice);

        escrow.transfer(msg.value);
        return (contractId, _numProposals);
    }

    function setProposalPrice(uint _price) public {
        require(msg.sender == escrow, "Only escrow can set proposal price");
        proposalToEtherRatio = _price;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getProposal(uint _proposalId) public view returns (address seller, uint numProposals) {
        require(_proposalId < proposals.length, "Invalid proposal ID");
        Proposal memory proposal = proposals[_proposalId];
        return (proposal.seller, proposal.numProposals);
    }

    function getContractList(address _seller) public view returns (uint[] memory) {
        uint[] memory contractList;
        uint counter = 0;
        for (uint i = 0; i < proposals.length; i++) {
            if (proposals[i].seller == _seller) {
                contractList[counter++] = i;
            }
        }
        return contractList;
    }
}
