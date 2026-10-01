function context = engine_rng_init(seed)
% Value-only snapshot; no shared RandStream handle and no global RNG changes.
validateattributes(seed,{'double'},{'real','finite','scalar','integer','>=',0,'<',2^32});
s=RandStream('mt19937ar','Seed',seed,'NormalTransform','Ziggurat');
context=struct('version',1,'type','mt19937ar','normal','Ziggurat','state',s.State);
end