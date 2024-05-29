// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

struct ContractInfo {
    uint256 id;
    uint256 jobIdcurent;
    string title;
    uint8 status;
    uint256 clientId;
    uint256 freelancerId;
}

contract SmartContract {
    struct Job {
        string title;
        string description;
        string signatureC; //chữ kí của clients
        string signatureF; //chỮ KÍ của Freelancers
        uint256 bids;
        uint256 jobIdcurent;
        uint256 clientId;
        uint256 freelancerId;
        uint8 status;
        //trạng thái status
        //0: đã tạo,1:freelancer đã ký 2:freelancer báo đã hoàn thành,3:client xác nhận(Hợp đồng kết thúc),
        //4:(bị hủy do freelancer),5:(bị hủy do client)
        address client;
        address freelancer;
        string cancelReason; // lí do hủy
    }
    mapping(uint256 => Job) public jobs;
    uint256 public jobId;

    /*
    + Hàm tạo hợp đồng
       - Chỉ có client mới được tạo
       - Truyền vào thông tin cần thiết( + lưu hình ảnh chữ kí base64,
                                         + lúc này client nạp tiền luôn,
                                         + bids fe không cho nhập mà phải truyền từ job)
       - số ví client sẽ được lưu lại/số ví freelancer để trống
    + Hàm ký hợp đồng
       - validate:Check ví người kí!= ví người tạo,check trạng thái hợp đồng
       - Lưu xuống status
       - chữ kí
    + Hàm hủy dành cho freelancer
       - validate:Check ví ==ví freelancer,check trạng thái hợp đồng(chưa bị hủy và đã được tạo)
       - Lưu xuống lí do hủy, chỉnh lại status
       - Hoàn tiền về cho client
    + Hàm hủy dành cho client
       - validate:Check ví ==ví client,check trạng thái hợp đồng(chưa bị hủy và đã được tạo, chưa được client xác nhận final)
       - Lưu xuống lí do hủy, chỉnh lại status
       - Hoàn tiền về cho freelancer
    + Hàm báo hoàn thành dành cho freelancer
       - validate:Check ví ==ví freelancer,check trạng thái hợp đồng(đã kí)
       - chỉnh lại status
    + Hàm báo kết thúc hợp đồng dành cho client
       - validate:Check ví ==ví client,check trạng thái hợp đồng(đã đc freelancer xác nhận)
       - chỉnh lại status
       - báo hợp đồng thành công
    ================== NHỮNG HÀM READ ====================
    + Lấy thông tin hợp đồng theo JOBID
    + Lấy thông tin tất cả hợp đồng theo ví
    + Lấy tất cả hợp đồng theo JOB
    =======================================================
    */

    constructor() {}

    // Events
    event JobCreated(uint256 indexed jobId);
    event JobAccepted(uint256 indexed jobId);
    event JobCompleted(uint256 indexed jobId);
    event JobApproved(uint256 indexed jobId);
    event FundsDeposited(uint256 amount);
    event FundsDepositedofFreelancer(uint256 amount);
    event FundsCancelForClient(uint256 amount);
    event FundsCancelForFreelancer(uint256 amount);
    event FundsCompleted(uint256 amount);
    event ContractCanceled(uint256 indexed jobId);

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
        require(jobs[id].status < 4, "Contract is canceled");
        _;
    }

    modifier contractNotAccepted(uint256 id) {
        // check hợp đồng chấp thuận chưa
        require(jobs[id].status < 1, "Contract is already accepted");
        _;
    }

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
        jobId++;
        jobs[jobId - 1] = Job({
            title: _title,
            description: _description,
            bids: _bids,
            status: 0,
            signatureC: _signature,
            signatureF: "",
            jobIdcurent: _jobId,
            clientId: _clientId,
            freelancerId: _freelancerId,
            client: msg.sender,
            freelancer: address(0),
            cancelReason: ""
        });
        // Phát sinh sự kiện trả về job ID
        emit JobCreated(jobId - 1);
        emit FundsDeposited(msg.value);

        return jobId - 1; //return về id hợp đồng
    }

    //check điều kiện[contract kh bị hủy, contract chưa đc accept
    function acceptContract(
        uint256 id,
        string memory signature
    ) external payable contractNotCanceled(id) contractNotAccepted(id) {
        require(
            msg.sender != jobs[id].client,
            "Client can't accept this contract"
        );
        require(msg.value ==  jobs[id].bids/2, "Insufficient amount sent");
        jobs[id].status = 1; // gán giá trị status=1 client chấp thuận
        jobs[id].signatureF = signature;
        jobs[id].freelancer = msg.sender; // Gán địa chỉ của freelancer
        // khi kí freelancer phải cọc 50% bids
        emit FundsDepositedofFreelancer(msg.value);
        emit JobAccepted(jobs[id].jobIdcurent);
    }

    ///kiểm tra giúp tôi hàm bên dưới
    /// write funtion finalizeContract and pay from escrows to freelancer

    // contract hoàn thành chỉ client đc thực hiện
    function finalizeContract(uint256 id) external onlyClient(id) {
        require(jobs[id].status == 2, "Contract is not finalized yet");
        jobs[id].status = 3;

        // Kiểm tra số dư của hợp đồng trước khi chuyển tiền
        //uint256 contractBalance = address(this).balance;
        //require(contractBalance >= jobs[id].bids/1000000000000000000, "Contract balance is insufficient");

        // Chuyển tiền sang tài khoản của freelancer
        // send all Ether to owner
        // (bool success,) = jobs[id].freelancer.call{value: jobs[id].bids}("");
        // require(success, "Failed to send Ether");
        payable(jobs[id].freelancer).transfer(jobs[id].bids+jobs[id].bids/2);
        emit JobApproved(jobs[id].jobIdcurent);
        emit FundsCompleted(jobs[id].jobIdcurent);
    }

    function rejectCompletion(uint256 id) external onlyClient(id) {
        require(
            jobs[id].status == 2,
            "Freelancer is not report completion yet"
        );
        jobs[id].status = 1;
    }

    function getJobInfoByCurrentJobId(
        uint256 currentJobId
    )
        external
        view
        returns (
            uint256,
            string memory,
            string memory,
            string memory,
            string memory,
            uint256,
            uint8,
            address,
            address,
            uint256,
            uint256
        )
    {
        for (uint256 i = 0; i < jobId; i++) {
            if (jobs[i].jobIdcurent == currentJobId && jobs[i].status <= 3) {
                return (
                    i,
                    jobs[i].title,
                    jobs[i].description,
                    jobs[i].signatureF,
                    jobs[i].signatureC,
                    jobs[i].bids,
                    jobs[i].status,
                    jobs[i].client,
                    jobs[i].freelancer,
                    jobs[i].freelancerId,
                    jobs[i].clientId
                );
            }
        }
        revert("Job not found or canceled");
    }

    function getContractById(uint256 id) external view returns (Job memory) {
        require(id < jobId, "Invalid job ID");
        Job memory contractInfo = jobs[id];
        require(contractInfo.status < 4, "Contract is canceled");

        return contractInfo;
    }

    ///Hàm lấy tất cả các hợp đồng của job theo job id
    function getAllContractsByJobId(
        uint256 jobIdInput
    ) external view returns (ContractInfo[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < jobId; i++) {
            if (jobs[i].jobIdcurent == jobIdInput) {
                count++;
            }
        }

        ContractInfo[] memory contracts = new ContractInfo[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < jobId; i++) {
            if (jobs[i].jobIdcurent == jobIdInput) {
                contracts[index] = ContractInfo({
                    id: i,
                    jobIdcurent: jobs[i].jobIdcurent,
                    title: jobs[i].title,
                    status: jobs[i].status,
                    freelancerId: jobs[i].freelancerId,
                    clientId: jobs[i].clientId
                });
                index++;
            }
        }
        return contracts;
    }

    function cancelContract(uint256 id, string memory reason) external {
        require(
            msg.sender == jobs[id].client || msg.sender == jobs[id].freelancer,
            "Only client or freelancer can cancel this contract"
        );

        //require(jobs[id].status ==0, "Contract cannot be canceled");

        if (msg.sender == jobs[id].client) {
            // Nếu client hủy hợp đồng
            require(
                jobs[id].status < 3,
                "Contract cannot be canceled by client at this stage"
            );

            jobs[id].status = 5; // Cập nhật trạng thái hủy bởi client
            jobs[id].cancelReason = reason; // Lưu lí do hủy
            payable(jobs[id].freelancer).transfer(jobs[id].bids+jobs[id].bids/2); // Chuyển tiền về cho freelancer
            emit FundsCancelForFreelancer(jobs[id].bids);
            emit ContractCanceled(jobs[id].jobIdcurent);
        } else {
            // Nếu freelancer hủy hợp đồng
            require(
                jobs[id].status < 2,
                "Contract cannot be canceled by freelancer at this stage"
            );

            jobs[id].status = 4; // Cập nhật trạng thái hủy bởi freelancer
            jobs[id].cancelReason = reason; // Lưu lí do hủy
            payable(jobs[id].client).transfer(jobs[id].bids+jobs[id].bids/2); // Chuyển tiền về cho client
            emit FundsCancelForClient(jobs[id].bids);
            emit ContractCanceled(jobs[id].jobIdcurent);
        }
    }

    function FreelancerNoSign(uint256 id, string memory reason) external {
        jobs[id].status = 4; // Cập nhật trạng thái hủy bởi freelancer
        jobs[id].cancelReason = reason; // Lưu lí do hủy
        payable(jobs[id].client).transfer(jobs[id].bids); // Chuyển tiền về cho client
        emit FundsCancelForClient(jobs[id].bids);
        emit ContractCanceled(jobs[id].jobIdcurent);
    }

    // freelancer báo hoàn thành
    function reportCompletion(uint256 id) external onlyFreelancer(id) {
        require(jobs[id].status == 1, "Contract is not accepted yet");
        jobs[id].status = 2;
        emit JobCompleted(jobs[id].jobIdcurent);
    }

    function getContractsByClient(
        address clientAddress
    ) external view returns (ContractInfo[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < jobId; i++) {
            if (jobs[i].client == clientAddress) {
                count++;
            }
        }

        ContractInfo[] memory clientContracts = new ContractInfo[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < jobId; i++) {
            if (jobs[i].client == clientAddress) {
                clientContracts[index] = ContractInfo({
                    id: i,
                    jobIdcurent: jobs[i].jobIdcurent,
                    title: jobs[i].title,
                    status: jobs[i].status,
                    freelancerId: jobs[i].freelancerId,
                    clientId: jobs[i].clientId
                });
                index++;
            }
        }
        return clientContracts;
    }

    function getContractsByFreelancer(
        address freelancerAddress
    ) external view returns (ContractInfo[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < jobId; i++) {
            if (jobs[i].freelancer == freelancerAddress) {
                count++;
            }
        }

        ContractInfo[] memory freelancerContracts = new ContractInfo[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < jobId; i++) {
            if (jobs[i].freelancer == freelancerAddress) {
                freelancerContracts[index] = ContractInfo({
                    id: i,
                    jobIdcurent: jobs[i].jobIdcurent,
                    title: jobs[i].title,
                    status: jobs[i].status,
                    freelancerId: jobs[i].freelancerId,
                    clientId: jobs[i].clientId
                });
                index++;
            }
        }
        return freelancerContracts;
    }

    function getContractsByClientId(
        uint256 clientId
    ) external view returns (ContractInfo[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < jobId; i++) {
            if (jobs[i].clientId == clientId) {
                count++;
            }
        }

        ContractInfo[] memory clientContracts = new ContractInfo[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < jobId; i++) {
            if (jobs[i].clientId == clientId) {
                clientContracts[index] = ContractInfo({
                    id: i,
                    jobIdcurent: jobs[i].jobIdcurent,
                    title: jobs[i].title,
                    status: jobs[i].status,
                    freelancerId: jobs[i].freelancerId,
                    clientId: jobs[i].clientId
                });
                index++;
            }
        }
        return clientContracts;
    }

    function getContractsByFreelancerId(
        uint256 freelancerId
    ) external view returns (ContractInfo[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < jobId; i++) {
            if (jobs[i].freelancerId == freelancerId) {
                count++;
            }
        }

        ContractInfo[] memory freelancerContracts = new ContractInfo[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < jobId; i++) {
            if (jobs[i].freelancerId == freelancerId) {
                freelancerContracts[index] = ContractInfo({
                    id: i,
                    jobIdcurent: jobs[i].jobIdcurent,
                    title: jobs[i].title,
                    status: jobs[i].status,
                    freelancerId: jobs[i].freelancerId,
                    clientId: jobs[i].clientId
                });
                index++;
            }
        }
        return freelancerContracts;
    }

    function getContractDetailByIndex(
        uint256 index
    ) external view returns (Job memory) {
        require(index < jobId, "Invalid index");
        Job memory contractInfo = jobs[index];
        return contractInfo;
    }
}