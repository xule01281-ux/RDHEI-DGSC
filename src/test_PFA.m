function [z1]=test_PFA(PFA)
N=length(PFA);
 for n=1:N
     
        z2=PFA{n};
        z21=z2(:,1);
        z22=z2(:,2);
        min=1000;
        
         f_n1=0;
        f_n0=0;
        for i=2:length(z21)
            if z22(i)<min&&z22(i)>1
                min=z22(i);
            end
           
            if z22(i)~=0
                f_n0=f_n0+1;
            end
            if z22(i)==1
                 f_n1= f_n1+1;
            end
        end
       
          if f_n1*2<f_n0+1
            for i=1:length(z21)
                n1=z22(i,1);
                if n1>=min
                 if i==1
                  z22(i)=ceil(n1/(min));
                 else
                    z22(i)=floor(n1/min);  
                 end
                else
                    z22(i)=1;
                end
            end
          end
        if n==1
            z1={[z21,z22]};
        else
            z1{end+1}=[z21,z22];
        end
 end
asa=1;