// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract SmartContract {
    struct Job {
        string title;
        string description;
        string signatureC;//chữ kí của clients
       string signatureF;//chỮ KÍ của Freelancers
        uint256 bids;
        uint256 jobIdcurent;
        uint256 clientId;
        uint256 freelancerId;
        uint8 status; //0: đã tạo(chưa kí),1:client đã chuyển tiề,2:freelancer đã ký 3:freelancer báo đã hoàn thành,4:client xác nhận
        address client;
        address freelancer;
        bool canceled; // True nếu hợp đồng đã bị hủy
    }
    mapping(uint256 => Job) public jobs;
    uint256 public jobId;
    address payable public escrow;

    constructor() {
        escrow = payable(msg.sender);
    }

    modifier onlyClient(uint256 id) {
        // validate chỉ có client mới thực hiện dc thao tác này
        require(
            msg.sender == jobs[id].client,
            "Only client can call this function"
        );
        _;
    }

    modifier onlyFreelancer(uint256 id) {
        // validate chỉ có freelancer mới thực hiện dc thao tác này
        require(
            msg.sender == jobs[id].freelancer,
            "Only freelancer can call this function"
        );
        _;
    }

    modifier contractNotCanceled(uint256 id) {
        //Valuda nếu hợp đồng đã Hủy thì kh đc hủy
        require(!jobs[id].canceled, "Contract is canceled");
        _;
    }

    modifier contractNotAccepted(uint256 id) {
        // check hợp đồng chấp thuận chưa
        require(jobs[id].status < 2, "Contract is already accepted");
        _;
    }

    function getBalance() public view returns (uint256) {
        //lấy thông tin tiền trong ví trung gian
        return address(escrow).balance;
    }
    event JobCreated(uint256 indexed jobId); // Sự kiện trả về job ID
    function createContract(
        string memory _title,
        string memory _description,
        string memory _signature,
        uint256 _bids,
        uint256 _jobId,
        uint256 _freelancerId,
        uint256 _clientId
    ) external payable returns (uint256) {
        require(msg.value == _bids, "Insufficient amount sent");
        //số  tiền gởi phải bằng với số tiền thầu dự án trong hợp đồng
        emit Ok();
        uint256 balanceBefore = getBalance();
        emit BalanceBefore(balanceBefore);
        jobId++;
        jobs[jobId - 1] = Job({
            title: _title,
            description: _description,
            bids: _bids,
            status: 0,
            signatureC:_signature,
            signatureF:'',
            jobIdcurent: _jobId,
            clientId: _clientId,
            freelancerId: _freelancerId,
            client: msg.sender,
            freelancer: address(0),
            canceled: false // Thêm trường canceled vào constructor
        });
        // Phát sinh sự kiện trả về job ID
        emit JobCreated(jobId - 1);
        // Nạp số tiền vào ví trung gian
        escrow.transfer(_bids);
        
        return jobId - 1; //return về id hợp đồng
    }

    //check điều kiện[contract kh bị hủy, contract chưa đc accept]
    function acceptContract(
        uint256 id,string memory signature
    ) external contractNotCanceled(id) contractNotAccepted(id) {
        jobs[id].status = 2; // gán giá trị status=2 client chấp thuận
        jobs[id].signatureF=signature;
        jobs[id].freelancer = msg.sender; // Gán địa chỉ của freelancer
    }

    // Khi không có ai apply thì báo hủy hợp đồng
    function cancelContract(
        uint256 id
    ) external onlyClient(id) contractNotCanceled(id) contractNotAccepted(id) {
        payable(jobs[id].client).transfer(jobs[id].bids);
        jobs[id].canceled = true;
    }

    // contract hoàn thành chỉ client đc thực hiện
    function finalizeContract(uint256 id) external onlyClient(id) {
        // check trạng thái của freelancer
        require(jobs[id].status == 3, "Contract is not finalized yet");
        payable(jobs[id].freelancer).transfer(jobs[id].bids); // chuyển tiền sang freelancer
    }

    
    function getJobInfoByCurrentJobId(uint256 currentJobId) external view returns ( uint256, string memory, string memory, string memory, string memory, uint256, uint8, address, address) {
    for (uint256 i = 0; i < jobId; i++) {
        if (jobs[i].jobIdcurent == currentJobId&&!jobs[i].canceled) {
            return (
                i,
                jobs[i].title,
                jobs[i].description,
                jobs[i].signatureF,
                jobs[i].signatureC,
                jobs[i].bids,
                jobs[i].status,
                jobs[i].client,
                jobs[i].freelancer
            );
        }
    }
    revert("Job not found or canceled");
}

   




    // freelancer báo hoàn thành
    function reportCompletion(uint256 id) external onlyFreelancer(id) {
        require(jobs[id].status == 2, "Contract is not accepted yet");
        jobs[id].status = 3;
    }

    event BalanceBefore(uint256 balance);
    event Ok();
}
