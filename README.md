# fivePipelineCPU
五级流水线的实现
\section{实验内容}
阅读实验原理实现以下模块：
\begin{enumerate}[(1)]
    \item Datapath，所有模块均可由实验三复用，需根据不同阶段，修改mux2为mux3(三选一选择器)，以及带有enable(使能)、clear(清除流水线)等信号的触发器，
    \item Controller，其中main decoder与alu decoder可直接复用，另需增加触发器在不同阶段进行信号传递
    \item 指令存储器inst\_mem(Single Port Ram)，数据存储器data\_mem(Single Port Ram)；同实验三一致，无需改动，
    \item 参照实验原理，在单周期基础上加入每个阶段所需要的触发器，重新连接部分信号。实验给出top文件，需兼容top文件端口设定。
    \item 实验给出仿真程序，最终以仿真输出结果判断是否成功实现要求指令。
\end{enumerate}
