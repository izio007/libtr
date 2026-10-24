function rc = unit_test_voi()
% UNIT_TEST_VOI Independent geometric and state-transition examples.
% Run explicitly; this test does not start services, create figures or edit files.
% Truth belongs only to this test. Production code receives angles and poses.
test_plane_angles();
test_projector_solution();
test_singular_and_reversed_rays();
test_first_tick_and_polynomial();
test_full_circle();
test_spatial_helix_and_ring();
test_late_observations_and_age();
test_missing_and_invalid_data();
test_geometry_loss_and_recovery();
test_final_observation();
test_final_prior_and_unavailable();
test_api_atomicity();
test_coordinate_translation();
test_correction();
rc = 0;
fprintf('VOI: 14 analytic/state test groups passed.\n');
end

function test_plane_angles()
% User tests 1--3, including the norm-preserving wrong spherical substitution.
[code,u,g] = voi_direction(-pi/6,-pi/6,eye(3));
expect(code==1,'-30/-30 must be admitted');
near(u,[sqrt(0.5);-0.5;-0.5],2e-14,'plane angles -> direction');
near(g.a_back,-pi/6,2e-14,'inverse plane angle a');
near(g.b_back,-pi/6,2e-14,'inverse plane angle b');
near(g.alpha,-atan(1/sqrt(2)),2e-14,'IV-quadrant azimuth');
near(g.beta,-pi/6,2e-14,'elevation');
wrong = [0.75;-sqrt(3)/4;-0.5];
near(norm(wrong),1,2e-14,'wrong spherical substitution retains unit norm');
near(asin(wrong(2))*180/pi,-25.6589062732553,1e-10, ...
    'inverse plane angle detects wrong spherical interpretation');

[code,u,g] = voi_direction(-pi/4,-pi/4,eye(3));
expect(code==0 && strcmp(g.reason,'BOUNDARY'),'exact d=0 is boundary');
expect(all(isnan(u)),'strict forward profile must not publish boundary ray');
near(g.d,0,32*eps,'boundary roundoff');
[code,~,~] = voi_direction(-pi/4,-pi/4+1e-9,eye(3));
expect(code==1,'inside boundary must remain valid');
[code,~,g] = voi_direction(-pi/4,-pi/4-1e-9,eye(3));
expect(code==0 && strcmp(g.reason,'INCOMPATIBLE_ANGLES'), ...
    'outside boundary must not be clipped to a valid ray');
[code,u,g] = voi_direction(-pi/3,-pi/3,eye(3));
expect(code==0 && strcmp(g.reason,'INCOMPATIBLE_ANGLES'),'-60/-60 refused');
near(g.d,-0.5,2e-14,'incompatible discriminant');
expect(all(isnan(u)),'incompatible angles have no published direction');

[code,~,g] = voi_direction(0,0,diag([1,1,-1]));
expect(code==0 && strcmp(g.reason,'INVALID_ROTATION'),'reflection refused');
[code,~,g] = voi_direction(0,0,diag([1,1,1.01]));
expect(code==0 && strcmp(g.reason,'INVALID_ROTATION'),'non-orthogonal frame refused');
C = [0,0,-1;0,1,0;1,0,0];
[code,u,g] = voi_direction(0,0,C);
expect(code==1,'vertical common-frame direction is valid');
near(u,[0;0;1],2e-14,'rotated vertical vector');
expect(isnan(g.alpha),'vertical azimuth is undefined');
near(g.beta,pi/2,2e-14,'vertical elevation');
end

function test_projector_solution()
% Exact target and projectors are derived in the companion mathematical text.
p = [1000/sqrt(2);-500;-500];
O = [zeros(3,1),[0;-500;0],zeros(3,1)];
U = [[1/sqrt(2);-0.5;-0.5],[sqrt(2/3);0;-1/sqrt(3)], ...
     [1/sqrt(2);-0.5;-0.5]];
[code,x,g] = voi_position(O(:,1:2),U(:,1:2),10,100,Inf);
expect(code==1,'two analytic rays must yield a position');
near(x,p,1e-9,'first two-ray solution');
near(g.condition_A,8+4*sqrt(3),1e-10,'two-ray condition number');
near(g.L,500,1e-12,'two-ray baseline');
[code,x,g] = voi_position(O,U,10,100,Inf);
expect(code==1,'repeated geometry at a new time remains usable');
near(x,p,1e-9,'three-ray solution');
near(g.condition_A,9+3*sqrt(7),1e-10,'three-ray condition number');
near(g.L,500,1e-12,'history baseline survives return to start');
expect(norm(O(:,end)-O(:,1))==0,'example really returns to first position');
expect(g.rms_residual<1e-9 && g.min_range>0,'exact forward rays');

% Skew lines: nearest points (1,0,0) and (1,0,1), hence midpoint (1,0,1/2).
O = [[0;0;0],[1;-2;1]];
U = [[1;0;0],[0;1;0]];
[code,x,g] = voi_position(O,U,0,100,Inf);
expect(code==1,'skew forward rays admitted');
near(x,[1;0;0.5],1e-12,'analytic skew-ray midpoint');
near(g.rms_residual,0.5,1e-12,'analytic transverse RMS');
near(g.min_range,1,1e-12,'analytic positive directed range');
limit=g.condition_A;
[code,~,g]=voi_position(O,U,0,limit,Inf);
expect(code==0 && strcmp(g.reason,'ILL_CONDITIONED'), ...
    'condition must be strictly below the configured limit');
[code,x,g] = voi_position(O,U,0,100,0.49);
expect(code==0 && strcmp(g.reason,'RESIDUAL_LIMIT'),'residual policy enforced');
expect(all(isnan(x)),'rejected residual does not publish candidate');
end

function test_singular_and_reversed_rays()
O = [[0;0;0],[0;1000;0]];
U = repmat([1;0;0],1,2);
[code,x,g] = voi_position(O,U,10,1e8,Inf);
expect(code==0 && strcmp(g.reason,'SINGULAR_GEOMETRY'), ...
    'large baseline alone cannot make parallel rays observable');
expect(all(isnan(x)) && g.L>10,'singular candidate rejected despite long baseline');
U(:,2)=-U(:,2);
[code,~,g] = voi_position(O,U,10,1e8,Inf);
expect(code==0 && strcmp(g.reason,'SINGULAR_GEOMETRY'),'antiparallel is singular too');
U=repmat([1+5e-11;0;0],1,2);
[code,~,g]=voi_position(O,U,10,1e24,Inf);
expect(code==0 && strcmp(g.reason,'SINGULAR_GEOMETRY'), ...
    'admitted norm roundoff cannot fabricate range observability');
U=repmat([1+1e-6;0;0],1,2);
[code,~,g]=voi_position(O,U,10,1e8,Inf);
expect(code==0 && strcmp(g.reason,'INVALID_INPUT'), ...
    'large unit-vector errors are not silently repaired');

O = [[0;0;0],[1;-2;1]];
U = [[-1;0;0],[0;1;0]];
[code,x,g] = voi_position(O,U,0,100,Inf);
expect(code==0 && strcmp(g.reason,'NONPOSITIVE_RANGE'), ...
    'line intersection behind a ray is not a forward-ray solution');
expect(all(isnan(x)),'backward candidate is unpublished');

O = [[0;0;0],[0;1;0]];
U = [[1;0;0],[1e6;-1;0]/norm([1e6;-1;0])];
[code,~,g] = voi_position(O,U,0,1e8,Inf);
expect(code==0 && strcmp(g.reason,'ILL_CONDITIONED'), ...
    'near-parallel rays require an explicit conditioning refusal');

[code,~,g] = voi_position(zeros(3,2),[[1;0;0],[0;1;0]],0,100,Inf);
expect(code==0 && strcmp(g.reason,'INSUFFICIENT_BASELINE'), ...
    'direction noise at a single origin cannot replace a baseline');
end

function test_first_tick_and_polynomial()
% User test 4. The second spline knot is a model endpoint, not a measurement.
c = config(); c.R0=1000;
o = struct('m',1,'t_obs',0,'a',-pi/6,'b',-pi/6, ...
           'origin',zeros(3,1),'C',eye(3),'nav_status',1);
[rc,s,out,d] = voi_step(c,struct(),0,o);
expect(rc==0 && out.phase==2 && out.basis==1,'first tick publishes prior phase');
expect(out.available && ~out.observed,'a prior is available but not observed range');
expect(strcmp(out.status,'APRIORI_SPLINE') && strcmp(d.action,'INIT'), ...
    'initialization publishes a spline in the same call');
expect(s.count==1,'initialization stores exactly one real ray');
p=[1000/sqrt(2);-500;-500];
near(out.point,p,1e-9,'initial R0 point');
[x,v,a]=voi_spline_eval(out.coeff,out.time_origin,[0,120,240]);
near(x,repmat(p,1,3),1e-9,'first spline exists over declared interval');
near(v,zeros(3,3),0,'constant spline velocity');
near(a,zeros(3,3),0,'constant spline acceleration');
near(out.coeff(:,2:4),zeros(3,3),0,'stationary-model polynomial coefficients');

coeff=[1,2,3,4;-5,0,0,0;7,-2,1,-1];
[x,v,a]=voi_spline_eval(coeff,10,[10,12]);
near(x,[1,49;-5,-5;7,-1],0,'generic cubic Horner values');
near(v,[2,62;0,0;-2,-10],0,'generic first derivative');
near(a,[6,54;0,0;2,-10],0,'generic second derivative');

o.a=0; o.b=0;
[rc,~,out]=voi_step(c,struct(),0,o);
expect(rc==0 && out.available,'zero angles are an actual observation');
near(out.point,[1000;0;0],1e-12,'zero-angle first ray');

% A positive configured range may vanish when added to a large double origin.
c.R0=1e-6; o.origin=1e12*ones(3,1);
[rc,s,out,d]=voi_step(c,struct(),0,o);
expect(rc==0 && d.accepted && s.count==1, ...
    'unrepresentable prior range does not discard its valid real ray');
expect(~out.available && ~out.observed && ~d.model_updated && ...
    strcmp(out.status,'UNAVAILABLE') && strcmp(out.reason,'NUMERIC_FAILURE'), ...
    'prior rounded to the ray origin cannot publish a fictitious positive range');
expect(all(isnan(out.point)) && all(isnan(out.coeff(:))), ...
    'unrepresentable prior remains unavailable');
near(s.origins(:,1),o.origin,0,'real observation origin is retained exactly');
end

function test_full_circle()
c=config(); c.R0=800; c.capacity=64;
p=[700;-500;-500];
n=25; theta=linspace(0,2*pi,n); times=240*(linspace(0,1,n).^1.3);
s=struct(); first_origin=[];
for i=1:n
    origin=[100+300*cos(theta(i));-100+300*sin(theta(i));80];
    if i==1, first_origin=origin; end
    C=observer_frame(p-origin,theta(i));
    obs=observation(p,origin,C,times(i));
    [rc,s,out,d]=voi_step(c,s,times(i),obs);
    expect(rc==0 && d.accepted,'circle observation accepted');
    if i==1
        expect(out.basis==1,'circle starts with R0 only');
    else
        expect(out.observed,'curved-path geometry reaches LS');
        near(out.point,p,1e-7,'circle known target');
    end
end
near(origin,first_origin,1e-10,'circle closes');
near(d.position_info.L,600,1e-9,'closed-circle history diameter');
expect(out.phase==4 && out.finalized && out.observed,'circle final observed model');
expect(s.count==n,'circle uses every retained real observation once');
near(out.coeff(:,2:4),zeros(3,3),0,'curve of observer does not move target model');
end

function test_spatial_helix_and_ring()
c=config(); c.capacity=12; c.R0=1800;
p=[2500;-700;900]; n=35;
theta=linspace(0,4*pi,n); times=240*(linspace(0,1,n).^1.6);
s=struct();
for i=1:n
    origin=[200+500*cos(theta(i));-100+500*sin(theta(i));60+12*theta(i)];
    C=observer_frame(p-origin,0.7*theta(i));
    obs=observation(p,origin,C,times(i));
    [rc,s,out,d]=voi_step(c,s,times(i),obs);
    expect(rc==0 && d.accepted,'helix observation accepted');
    if i>1
        expect(out.observed,'helix geometry is observable');
        near(out.point,p,2e-6,'helix known target after ring wrap');
    end
    expect(s.count==min(i,c.capacity),'ring counts real retained observations');
end
expect(out.phase==4 && s.count==c.capacity,'bounded helix state');
active=s.t_obs(1:s.count);
near(sort(active),times(end-c.capacity+1:end),1e-12,'ring contains latest acquisition times');
expect(d.position_info.L>100,'retained helix has usable baseline');
end

function test_late_observations_and_age()
c=config(); c.age_max=60;
p=[700;-500;-500];
[rc,s,~]=voi_step(c,struct(),0,observation(p,[0;0;0],eye(3),0));
expect(rc==0,'late-data setup');
C=observer_frame(p-[0;-500;0],0.4);
[rc,s,out]=voi_step(c,s,100,observation(p,[0;-500;0],C,40));
expect(rc==0 && out.observed && out.fresh,'delayed sample accepted at its own pose');
near(out.age,60,1e-12,'age uses acquisition time');
C=observer_frame(p-[0;100;200],1.7);
late=observation(p,[0;100;200],C,25);
[rc,s,out]=voi_step(c,s,200,late);
expect(rc==0 && out.observed && ~out.fresh,'stale static geometry remains available');
near(out.point,p,1e-7,'out-of-order sample uses its own historical frame');
near(out.age,160,1e-12,'older arrival cannot replace latest support time');
expect(s.count==3,'out-of-order valid observation stored');
before=s;
[rc,s,out,d]=voi_step(c,s,210,late);
expect(rc==0 && ~d.accepted && d.data_state==0,'retained duplicate refused');
expect(strcmp(out.reason,'DUPLICATE_OBSERVATION'),'duplicate reason');
near(out.point,before.point,0,'duplicate preserves position exactly');
near(s.origins,before.origins,0,'duplicate preserves history exactly');
expect(s.count==before.count,'duplicate does not add weight');

% Exact requested t_obs=180, t_cur=240 example.
c.age_max=30;
[~,s,~]=voi_step(c,struct(),0,observation(p,[0;0;0],eye(3),0));
[rc,~,out]=voi_step(c,s,240,observation(p,[0;-500;0],eye(3),180));
expect(rc==0 && out.observed && out.finalized,'late last sample processed before final');
near(out.age,60,1e-12,'180-to-240 age');
expect(~out.fresh && out.available,'freshness is separate from static validity');
end

function test_missing_and_invalid_data()
c=config(); p=[700;-500;-500];
[~,s,out]=voi_step(c,struct(),0,observation(p,[0;0;0],eye(3),0));
initial=s;
missing=struct('m',0,'a',NaN,'b',NaN,'origin',NaN,'C',NaN);
[rc,s,out,d]=voi_step(c,s,10,missing);
expect(rc==0 && d.data_state==-1 && ~d.accepted,'missing ignores unused numeric fields');
expect(out.phase==2 && strcmp(out.status,'HOLD_APRIORI'),'missing retains prior phase');
near(s.point,initial.point,0,'missing preserves prior');
near(s.coeff,initial.coeff,0,'missing preserves prior coefficients');
expect(s.count==1,'missing does not synthesize a ray');

unknown=struct('m',1,'t_obs',20,'a',0,'b',0,'nav_status',-1);
[rc,s,out,d]=voi_step(c,s,20,unknown);
expect(rc==0 && d.data_state==-1 && ~d.accepted,'unknown navigation is U');
expect(s.count==1 && out.phase==2,'unknown navigation leaves observation history');
bad=observation(p,[0;-500;0],eye(3),30); bad.a=-pi/3; bad.b=-pi/3;
[rc,s,~,d]=voi_step(c,s,30,bad);
expect(rc==0 && d.data_state==0 && ~d.accepted,'known impossible angles are F');
expect(s.count==1,'invalid angles not stored');
bad=observation(p,[0;-500;0],eye(3),40); bad.nav_status=0;
[rc,s,~,d]=voi_step(c,s,40,bad);
expect(rc==0 && d.data_state==0 && ~d.accepted,'known invalid navigation is F');
expect(s.count==1,'invalid navigation not stored');
[rc,s,out]=voi_step(c,s,50,observation(p,[0;-500;0],eye(3),50));
expect(rc==0 && out.phase==3 && out.observed,'valid second ray enters LS');
near(out.point,p,1e-7,'LS setup before hold');
last=s;
[rc,s,out,d]=voi_step(c,s,60,struct('m',0));
expect(rc==0 && out.phase==3 && strcmp(out.status,'HOLD_LS'),'missing does not reset LS to prior');
expect(d.data_state==-1 && ~d.accepted,'LS hold is U');
near(out.point,last.point,0,'LS hold preserves accepted position');
near(out.coeff,last.coeff,0,'LS hold preserves accepted coefficients');
near(s.origins,last.origins,0,'LS hold preserves real history');
expect(s.count==last.count,'LS hold keeps sample count');

bad=observation(p,[0;100;100],eye(3),70); bad.C=diag([1,1,-1]);
[rc,s,out,d]=voi_step(c,s,70,bad);
expect(rc==0 && out.phase==3 && d.data_state==0 && ~d.accepted,'bad frame holds LS');
near(s.point,last.point,0,'bad frame cannot overwrite solution');
end

function test_final_observation()
c=config(); c.R0=800; p=[1000/sqrt(2);-500;-500];
[~,s,out]=voi_step(c,struct(),0,observation(p,[0;0;0],eye(3),0));
expect(~out.observed,'first sample has no observed range');
[rc,s,out,d]=voi_step(c,s,240,observation(p,[0;-500;0],eye(3),240));
expect(rc==0 && d.accepted && s.count==2,'final sample included before freeze');
expect(out.phase==4 && out.observed && strcmp(out.status,'FINAL_C2_SPLINE'), ...
    'finalization contains just-computed LS');
near(out.point,p,1e-7,'final sample changes prior to true analytic position');
near(out.finalized_at,240,0,'actual finalization time');
before=s;
[rc,s,out,d]=voi_step(c,s,250,struct('m',0));
expect(rc==0 && isequaln(s,before) && strcmp(d.action,'FROZEN'),'final context immutable');
near(out.age,10,0,'age advances while frozen coefficients do not');
[rc,s,out]=voi_step(c,s,240,struct('m',0));
expect(rc==0 && isequaln(s,before),'frozen model is readable at finalization time');
near(out.age,0,0,'frozen read has requested age');

[~,s,~]=voi_step(c,struct(),0,observation(p,[0;0;0],eye(3),0));
[rc,~,out]=voi_step(c,s,245,observation(p,[0;-500;0],eye(3),230));
expect(rc==0 && out.observed && out.finalized,'first call after horizon finalizes');
near(out.finalized_at,245,0,'processing time is not forged as horizon time');
near(out.interval,[0,240],0,'modeled interval keeps requested horizon');
end

function test_geometry_loss_and_recovery()
c=config(); c.capacity=2;
p=[1000;0;0];
[~,s,out]=voi_step(c,struct(),0,observation(p,[0;0;0],eye(3),0));
first=out.point;
[rc,s,out,d]=voi_step(c,s,10,observation(p,[100;0;0],eye(3),10));
expect(rc==0 && d.accepted && ~out.observed,'parallel follow-up remains a prior');
near(out.point,first,0,'prior remains attached to the first ray');

p=[700;-500;-500];
[~,s,~]=voi_step(c,struct(),0,observation(p,[0;-500;0],eye(3),0));
[rc,s,out]=voi_step(c,s,10,observation(p,p-[1000;0;0],eye(3),10));
expect(rc==0 && out.observed,'geometry-loss setup has an observed position');
previous=out;
[rc,s,out,d]=voi_step(c,s,20,observation(p,p-[2000;0;0],eye(3),20));
expect(rc==0 && d.accepted && ~d.model_updated,'valid ray can be retained without position update');
expect(d.geometry_state==0 && strcmp(out.reason,'SINGULAR_GEOMETRY'), ...
    'window losing its transverse baseline refuses the new position');
expect(out.phase==3 && out.observed && strcmp(out.status,'HOLD_LS'), ...
    'geometry loss preserves the last observed model and phase');
near(out.point,previous.point,0,'geometry loss preserves exact last point');
near(out.coeff,previous.coeff,0,'geometry loss preserves exact last polynomial');
near(out.age,10,0,'unusable new ray does not refresh the last solution');
near(s.last_observation_time,20,0,'new ray timestamp remains separate from support age');
[rc,~,out,d]=voi_step(c,s,30,observation(p,[0;500;100],eye(3),30));
expect(rc==0 && d.model_updated && out.phase==3,'transverse geometry recovers');
near(out.point,p,1e-7,'recovered point uses retained new geometry');
near(out.age,0,0,'successful LS refreshes support age');
end

function test_final_prior_and_unavailable()
c=config(); p=[700;-500;-500];
[~,s,out]=voi_step(c,struct(),0,struct('m',0));
expect(~out.available && out.phase==1,'first missing sample has no fictitious prior');
[rc,~,out]=voi_step(c,s,240,struct('m',0));
expect(rc==0 && out.phase==4 && ~out.available && ~out.observed, ...
    'deadline alone cannot create observability');
expect(strcmp(out.status,'FINAL_UNAVAILABLE'),'unavailable final result');
[~,s,~]=voi_step(c,struct(),0,observation(p,[0;0;0],eye(3),0));
old=s.point;
[rc,~,out]=voi_step(c,s,240,struct('m',0));
expect(rc==0 && out.available && ~out.observed && out.phase==4,'prior finalization stays prior');
expect(strcmp(out.status,'FINAL_APRIORI'),'prior is not relabeled as measured');
near(out.point,old,0,'final prior point retained');
end

function test_api_atomicity()
c=config(); p=[700;-500;-500];
[~,s,~]=voi_step(c,struct(),0,observation(p,[0;0;0],eye(3),0));
before=s;
[rc,after,out]=voi_step(c,s,0,struct('m',0));
expect(rc==1 && isequaln(after,before) && strcmp(out.status,'API_ERROR'), ...
    'repeated nonfinal current time refuses atomically');
[rc,after,~]=voi_step(c,s,NaN,struct('m',0));
expect(rc==1 && isequaln(after,before),'NaN time refuses atomically');
changed=c; changed.R0=c.R0+1;
[rc,after,~]=voi_step(changed,s,1,struct('m',0));
expect(rc==1 && isequaln(after,before),'configuration cannot change an existing context');
[rc,after,~]=voi_step(c,s,1,struct());
expect(rc==1 && isequaln(after,before),'missing outer m field is API refusal');
corrupt=s; corrupt.schema_version=999;
[rc,after,~]=voi_step(c,corrupt,1,struct('m',0));
expect(rc==1 && isequaln(after,corrupt),'invalid saved context is returned unchanged');

empty_context=struct();
wide=c; wide.time_start=-1e308; wide.time_end=1e308;
[rc,after,out]=voi_step(wide,empty_context,0,struct('m',0));
expect(rc==1 && isequaln(after,empty_context) && strcmp(out.reason,'INVALID_CONFIG'), ...
    'finite endpoints with overflowing duration refuse before initialization');
wide.time_end=-5e307;
[rc,after,out]=voi_step(wide,empty_context,1e308,struct('m',0));
expect(rc==1 && isequaln(after,empty_context) && strcmp(out.reason,'INVALID_CURRENT_TIME'), ...
    'overflowing processing-time offset refuses atomically');
huge=c; huge.capacity=flintmax;
[rc,after,out]=voi_step(huge,empty_context,0,struct('m',0));
expect(rc==1 && isequaln(after,empty_context) && ...
       strcmp(out.reason,'CONTEXT_ALLOCATION_FAILURE'), ...
    'unaddressable ring allocation reports API failure without partial context');

future=observation(p,[0;-500;0],eye(3),10);
[rc,after,out,d]=voi_step(c,s,5,future);
expect(rc==0 && ~d.accepted && d.data_state==0,'future acquisition time refuses observation');
near(out.point,before.point,0,'future observation cannot change accepted point');
expect(after.count==before.count,'future observation not stored');
end

function test_coordinate_translation()
p=[1000/sqrt(2);-500;-500];
O=[zeros(3,1),[0;-500;0],[0;100;200]];
U=zeros(3,size(O,2));
for i=1:size(O,2), U(:,i)=(p-O(:,i))/norm(p-O(:,i)); end
[code,x,~]=voi_position(O,U,10,1e8,Inf);
expect(code==1,'reference before coordinate translation');
near(x,p,1e-7,'reference known target');
shift=[1e9;-2e9;3e9];
[code,y,g]=voi_position(bsxfun(@plus,O,shift),U,10,1e8,Inf);
expect(code==1,'translated shared Cartesian frame remains valid');
% 3e9-m origin has a double ULP near 4.8e-7 m; this bound includes representation.
near(y-shift,p,1e-5,'translation covariance within large-origin roundoff');
expect(g.rms_residual<1e-5,'large origin does not become spurious residual');
end

function test_correction()
% Independent rest-to-rest solution for H=3, from x=0 to x=6:
% x=t^3; x=1+3s+3s^2-2s^3; x=5+3s-3s^2+s^3, on three unit intervals.
H=3; zero=zeros(3,1); target=[6;0;0]; tolerance=5e-12;
[rc,waiting,out]=voi_correction_step(H,struct(),-2,[]);
expect(rc==0 && ~out.ready,'missing first target cannot create a correction signal');
[rc,~,out]=voi_correction_step(H,waiting,-1,target);
expect(rc==0 && out.ready && ~out.transitioning,'first available target is immediate');
near(out.position,target,0,'first available nonzero target is not delayed');
near(out.velocity,zero,0,'first available target starts at rest');
near(out.acceleration,zero,0,'first available target has no invented acceleration');
[rc,seed,out]=voi_correction_step(H,struct(),-1,zero);
expect(rc==0 && out.ready,'first correction target initializes a stationary signal');
near(out.position,zero,0,'initial correction position');
near(out.velocity,zero,0,'initial correction velocity');
near(out.acceleration,zero,0,'initial correction acceleration');
[rc,base,initial]=voi_correction_step(H,seed,0,target);
expect(rc==0 && initial.ready && initial.transitioning,'changed target starts correction');
near(initial.position,zero,tolerance,'transition starts without a position jump');
near(initial.correction_end,3,0,'three-second transition endpoint');
times=[0,1,1.5,2,3,4];
positions=[0,1,3,5,6,6];
velocities=[0,3,4.5,3,0,0];
accelerations=[0,6,0,-6,0,0];
for i=1:numel(times)
    [rc,out]=voi_correction_eval(base,times(i));
    expect(rc==0 && out.ready,'analytic correction knot is evaluable');
    near(out.position,[positions(i);0;0],tolerance,'correction analytic position');
    near(out.velocity,[velocities(i);0;0],tolerance,'correction analytic velocity');
    near(out.acceleration,[accelerations(i);0;0],tolerance,'correction analytic acceleration');
end
expect(~out.transitioning,'signal holds its endpoint after transition');

% Both sides of each internal join and of the final hold, not only knot selection.
delta=1/256;
times=[1-delta,1+delta,2-delta,2+delta,3-delta,3+delta];
positions=[1-3*delta+3*delta^2-delta^3,1+3*delta+3*delta^2-2*delta^3, ...
    5-3*delta-3*delta^2+2*delta^3,5+3*delta-3*delta^2+delta^3,6-delta^3,6];
velocities=[3-6*delta+3*delta^2,3+6*delta-6*delta^2, ...
    3+6*delta-6*delta^2,3-6*delta+3*delta^2,3*delta^2,0];
accelerations=[6-6*delta,6-12*delta,-6+12*delta,-6+6*delta,-6*delta,0];
for i=1:numel(times)
    [rc,out]=voi_correction_eval(base,times(i));
    expect(rc==0,'one-sided correction sample is evaluable');
    near(out.position,[positions(i);0;0],tolerance,'C2 join position');
    near(out.velocity,[velocities(i);0;0],tolerance,'C2 join velocity');
    near(out.acceleration,[accelerations(i);0;0],tolerance,'C2 join acceleration');
end

% Missing and repeated targets continue the same polynomial at the same origin.
[rc,held,out]=voi_correction_step(H,base,0.25,[]);
expect(rc==0 && out.transitioning,'missing target continues an active correction');
near(out.position,[1/64;0;0],tolerance,'missing target still advances correction time');
near(out.coeff,initial.coeff,0,'missing target preserves coefficients exactly');
near(out.time_origin,initial.time_origin,0,'missing target cannot restart the clock');
near(out.correction_end,3,0,'missing target preserves completion time');
[rc,held,out]=voi_correction_step(H,held,0.5,target);
expect(rc==0 && out.transitioning,'repeated target continues an active correction');
near(out.position,[1/8;0;0],tolerance,'repeated target keeps original progress');
near(out.coeff,initial.coeff,0,'repeated target preserves coefficients exactly');
[rc,~,out]=voi_correction_step(H,held,4,[]);
expect(rc==0 && ~out.transitioning,'missing input after completion holds endpoint');
near(out.position,target,tolerance,'completed correction holds target');
near(out.velocity,zero,tolerance,'completed correction has zero velocity');
near(out.acceleration,zero,tolerance,'completed correction has zero acceleration');
[rc,out]=voi_correction_eval(held,0.25);
expect(rc==0,'read-only evaluation can precede the last processing tick');
near(out.position,[1/64;0;0],tolerance,'historical evaluation within current transition');

% Replan inside a segment with NONZERO position, velocity and acceleration.
% Old state at t=1/2 is (1/8,3/4,3); new target is zero and H remains 3.
[rc,replanned,seam]=voi_correction_step(H,base,0.5,zero);
expect(rc==0 && seam.transitioning,'changed target replans an active correction');
near(seam.position,[1/8;0;0],tolerance,'replanning preserves position');
near(seam.velocity,[3/4;0;0],tolerance,'replanning preserves nonzero velocity');
near(seam.acceleration,[3;0;0],tolerance,'replanning preserves nonzero acceleration');
near(seam.correction_end,3.5,0,'replanning declares its own completion time');
times=[0.5,1.5,2.5,3.5,4.5];
positions=[1/8,19/16,5/16,0,0];
velocities=[3/4,3/16,-15/16,0,0];
accelerations=[3,-33/8,15/8,0,0];
for i=1:numel(times)
    [rc,out]=voi_correction_eval(replanned,times(i));
    expect(rc==0,'replanned analytic knot is evaluable');
    near(out.position,[positions(i);0;0],tolerance,'replanned analytic position');
    near(out.velocity,[velocities(i);0;0],tolerance,'replanned analytic velocity');
    near(out.acceleration,[accelerations(i);0;0],tolerance,'replanned analytic acceleration');
end
[rc,left]=voi_correction_eval(base,0.5-delta);
expect(rc==0,'old transition defines the incoming side of the replan seam');
near(left.position,[(0.5-delta)^3;0;0],tolerance,'incoming replan position');
near(left.velocity,[3*(0.5-delta)^2;0;0],tolerance,'incoming replan velocity');
near(left.acceleration,[6*(0.5-delta);0;0],tolerance,'incoming replan acceleration');
[rc,right]=voi_correction_eval(replanned,0.5+delta);
expect(rc==0,'new transition defines the outgoing side of the replan seam');
near(right.position,[1/8+3*delta/4+3*delta^2/2-19*delta^3/16;0;0], ...
    tolerance,'outgoing replan position');
near(right.velocity,[3/4+3*delta-57*delta^2/16;0;0], ...
    tolerance,'outgoing replan velocity');
near(right.acceleration,[3-57*delta/8;0;0],tolerance,'outgoing replan acceleration');

% The same scalar geometry must act independently in all three coordinates.
[rc,spatial,~]=voi_correction_step(H,seed,0,[0;6;-6]);
expect(rc==0,'spatial correction initialized');
[rc,out]=voi_correction_eval(spatial,1);
expect(rc==0,'spatial correction evaluated');
near(out.position,[0;1;-1],tolerance,'spatial correction position');
near(out.velocity,[0;3;-3],tolerance,'spatial correction velocity');
near(out.acceleration,[0;6;-6],tolerance,'spatial correction acceleration');

% Doubling H preserves positions while dividing velocity by 2 and acceleration by 4.
[rc,slow,~]=voi_correction_step(6,struct(),-1,zero);
expect(rc==0,'scaled-horizon correction initialized');
[rc,slow,~]=voi_correction_step(6,slow,0,target);
expect(rc==0,'scaled-horizon correction started');
[rc,out]=voi_correction_eval(slow,2);
expect(rc==0,'scaled-horizon correction evaluated');
near(out.position,[1;0;0],tolerance,'horizon scaling preserves geometric position');
near(out.velocity,[1.5;0;0],tolerance,'horizon scaling of velocity');
near(out.acceleration,[1.5;0;0],tolerance,'horizon scaling of acceleration');

% API refusals are atomic; finite samples before the current plan are unavailable.
[rc,after,~]=voi_correction_step(H+1,base,0.5,target);
expect(rc==1 && isequaln(after,base),'correction horizon cannot change existing context');
[rc,after,~]=voi_correction_step(H,base,0,target);
expect(rc==1 && isequaln(after,base),'repeated correction tick refuses atomically');
[rc,after,~]=voi_correction_step(H,base,-0.5,target);
expect(rc==1 && isequaln(after,base),'backward correction tick refuses atomically');
[rc,after,~]=voi_correction_step(H,base,NaN,target);
expect(rc==1 && isequaln(after,base),'nonfinite correction tick refuses atomically');
[rc,after,~]=voi_correction_step(H,base,0.5,[1;2]);
expect(rc==1 && isequaln(after,base),'wrong target shape refuses atomically');
[rc,after,~]=voi_correction_step(H,base,0.5,[NaN;0;0]);
expect(rc==1 && isequaln(after,base),'nonfinite target refuses atomically');
empty_context=struct();
[rc,after,~]=voi_correction_step(0,empty_context,0,zero);
expect(rc==1 && isequaln(after,empty_context),'invalid initial horizon refuses atomically');
[rc,~]=voi_correction_eval(replanned,0.5-delta);
expect(rc==1,'new plan cannot evaluate history preceding its own origin');
[rc,~]=voi_correction_eval(base,NaN);
expect(rc==1,'nonfinite evaluation time is refused');
end

function c=config()
c=struct('R0',800,'Lmin',10,'kappa_max',1e8,'capacity',64, ...
    'time_start',0,'time_end',240,'age_max',Inf,'residual_max',Inf);
end

function obs=observation(p,origin,C,tobs)
% Independent forward data model: known point -> normalized displacement -> angles.
v=p-origin;
u_local=C.'*(v/norm(v));
expect(u_local(1)>0,'test model must satisfy the declared forward hemisphere');
obs=struct('m',1,'t_obs',tobs,'a',asin(u_local(2)),'b',asin(u_local(3)), ...
    'origin',origin,'C',C,'nav_status',1);
end

function C=observer_frame(v,phase)
% A proper frame with changing yaw, pitch and roll; line of sight stays forward.
yaw=atan2(v(2),v(1))+0.12*sin(0.7+phase);
pitch=-atan2(v(3),hypot(v(1),v(2)))+0.08*cos(0.4+phase);
roll=0.3*sin(0.2+1.3*phase);
Rz=[cos(yaw),-sin(yaw),0;sin(yaw),cos(yaw),0;0,0,1];
Ry=[cos(pitch),0,sin(pitch);0,1,0;-sin(pitch),0,cos(pitch)];
Rx=[1,0,0;0,cos(roll),-sin(roll);0,sin(roll),cos(roll)];
C=Rz*Ry*Rx;
end

function near(actual,expected,tolerance,label)
expect(isequal(size(actual),size(expected)),[label,': dimensions']);
expect(all(isfinite(actual(:))) && all(isfinite(expected(:))),[label,': finite values']);
err=max(abs(actual(:)-expected(:)));
if isempty(err), err=0; end
if err>tolerance
    error('VOI:NumericCheck','%s: error %.17g exceeds %.17g',label,err,tolerance);
end
end

function expect(condition,label)
if ~isscalar(condition) || ~condition
    error('VOI:Check','%s',label);
end
end
