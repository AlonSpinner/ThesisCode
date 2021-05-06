%map - 0:100 grid with 3 doors
doorWidth=2;
doors=[10,50,80];
map=zeros(1,100);
for ii=1:length(doors)
    map(doors(ii)-doorWidth/2:doors(ii)+doorWidth/2)=1;
end

std_measure=2;
std_init=4;
std_process=1;

%define measurement function
afcn_gauss=@(x,mu,sig) 1/(2*pi*sig^2)^(1/2)*exp(-1/2*(x-mu).^2/sig^2);
x_door_map=linspace(0,100,100);
p_door_map=...
afcn_gauss(x_door_map,doors(1),std_measure)+...
afcn_gauss(x_door_map,doors(2),std_measure)+...
afcn_gauss(x_door_map,doors(3),std_measure);
p_door_map=p_door_map/length(doors); %divide so integral over prob fcn is 1
afcn_p_door=@(x) interp1(x_door_map,p_door_map,x);


M=100; %Number of Particles
Chi=[linspace(0,length(map),M)', ones(M,1)/M];  %array of particles and associated weights
u_t = 5; %control input (constant motion in x-direction)
max_moves = 10;
x_t=1;

for mv = 1:max_moves
    % move ACTUAL robot
    x_t=motion_model(u_t,x_t,std_process,map);
    %take measurement
    z_t=take_measurement(x_t,map,std_measure);
    % apply particle filter
    Chi = MCL(Chi,u_t,z_t,std_process,afcn_p_door,map);
end

fprintf('x_t = %g, guess = %g after %g steps\n',x_t,mean(Chi(:,1)),max_moves);

function [Chi_t,ChiBar_t] =  MCL(Chi_tm1,u_t,z_t,std_process,afcn_p_door,map)
%Implements Monte Carlo Localization (MCL) algorithm, Table 8.2, page 252,
%"Probabilistic Robotics"

%initalize
M = size(Chi_tm1,1);
[ChiBar_t,Chi_t] = deal(zeros(size(Chi_tm1)));
N = 0; %normalization factor

%Sample Particles
for m = 1:M %for each particle
    x_tm1 = Chi_tm1(m,1); %get previous state
    x_t = motion_model(u_t,x_tm1,std_process,map); %update via motion model
    w_t = measurement_model(z_t, x_t,afcn_p_door); %obtain weigtht from measurement model 
    ChiBar_t(m,:) = [x_t,w_t]; %save current states and their weights
    N = N+w_t; %sum weight for normalization later on
end
% normalize
cumwt = cumsum(ChiBar_t(:,2))/N; %normalize the new distribution to be a PDF
for m = 1:M %Resampling step
    %draw m-th sample with probability proportional to wt with two methods:
    swt = rand; %1.) randomly sample
    index = find(cumwt>= swt,1,'first');
    x_t = ChiBar_t(index,1);
    Chi_t(m,:) = [x_t,1/M]; %add particle to CHI
end
end
function x_t=motion_model(u_t,x_tm1,std_process,map)
x_t = x_tm1 + u_t + std_process*randn(1);
x_t = min(x_t,length(map));
x_t = max(x_t,1);
end
function w_t = measurement_model(z_t, x_t, afn_p_door)
% evaluate likelihood of measurement z_t given prior with mean x_t
if z_t==1 
    w_t=afn_p_door(x_t);
else
    w_t=1e-10;
end
end
function z_t=take_measurement(x_t,map,std_measure)
x_4meas=x_t+randn(1)*std_measure;
x_4meas = min(x_4meas,length(map));
x_4meas = max(x_4meas,1);
if map(floor(x_4meas)) || map(ceil(x_4meas))
    z_t=1;
else
    z_t=0;
end
end