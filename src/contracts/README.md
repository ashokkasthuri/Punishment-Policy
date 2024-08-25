<!--
 * @Author: ashokkasthuri ashokk@smu.edu.sg
 * @Date: 2024-08-25 19:30:10
 * @LastEditors: ashokkasthuri ashokk@smu.edu.sg
 * @LastEditTime: 2024-08-25 19:30:31
 * @FilePath: /smart-contracts/src/contracts/README.md
 * @Description: 这是默认设置,请设置`customMade`, 打开koroFileHeader查看配置 进行设置: https://github.com/OBKoro1/koro1FileHeader/wiki/%E9%85%8D%E7%BD%AE
-->
Steps to run the code.
1. Deploy the ACC, RC and JC on the Ethereum blockchain network. In my case, I just built a local private Ethereum blockchain network using three devices, i.e., a desktop PC and two Raspberry Pi's. Each device has the geth client installed.

2. Add the address of the ACC into the lookuptable of the RC and store the address of the JC to the jc variable of the ACC. This is to enable the interactions among the contracts.

3. Add the required information for access control to the smart contracts, e.g., access control policies.

4. Run the monitor.js javascript on the object side and the requester.js on the subject side to test the access control.