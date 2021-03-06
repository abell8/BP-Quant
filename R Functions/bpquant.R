bpquant <- function(protein_sig, pi_not){
  
## implement some checks ##
# pi_not must be between 0 and 1 #
if(pi_not > 1 | pi_not < 0) stop("The background frequency of the zero signature must be between 0 and 1")

## signatures can only contain values equal to -1, 1, or 0
if(sum(apply(protein_sig, 1, function(x) sum(!(x %in% c(1,-1,0)))))> 0 ) stop("Entries in the signatures matrix may only take values of -1, 1, or 0")


############# generate parameters associated with signature counts and probabilities #############
    
  ## generate a list of unique signatures ##
  sigs = unique(protein_sig)
  
  ## store number of unique signatures ##
  uniq_sigs = nrow(sigs)
  
  #### count occurences of each signature ####
  ## save current signatures as character strings ##
  sig_str = apply(protein_sig,1,paste,collapse="")
  
  counts = NULL
  for(j in 1:uniq_sigs){
  	## count occurences of each unique signatures ##
    counts[j] = sum(sig_str==paste(sigs[j,],collapse=""))
  }
  
  ## order signatures by count##
  cnt.ord = counts[order(counts, decreasing=T)]
  if(nrow(sigs) > 1){sig.ord = sigs[order(counts, decreasing=T),]}else{sig.ord = sigs}
  
  ## set zero signature first ##
  z.sig = which(apply(abs(sig.ord),1,sum)==0)
  if(length(z.sig) == 0){pi_probs = rep((1 - pi_not)/uniq_sigs, uniq_sigs)}else{
    sig.ord = rbind(sig.ord[z.sig,],sig.ord[-z.sig,])
    cnt.ord = c(cnt.ord[z.sig],cnt.ord[-z.sig])
    
    ## calculate prior probabilities associated with non-zero signatures ##
    pi_probs = rep((1 - pi_not)/(uniq_sigs - 1), uniq_sigs)
    pi_probs[1] = pi_not
  }
  
  ## identify which unique signature each row matches ##
  counts_ids = NULL
  for(j in 1:nrow(sig.ord)){
    counts_ids[sig_str==paste(sig.ord[j,],collapse="")] = j
  }
  
  ############## generate possible proteoforms ####################
  ## specify the number of unique signatures observed ##
  nu = length(pi_probs)
  
  #### build matrix of possible proteoforms ####
  ## number of possible proteoform presence/absence combinations ##
  n_combos = 2^nu

  ## number of reps for each iteration ##
  n_reps = rep(1,nu)
  if(nu > 1){
    for(j in 2:nu){
      n_reps[j] = n_reps[j-1]*2
    }
  }
 
  ## construct matrix of all possible proteoform configurations ## 
  mat = matrix(0, nrow = n_combos, ncol = nu)
  mat[,1] = rep(c(0,1),each = n_reps[nu])
  if(nu > 1){
    for(j in 2:nu){
      mat[,j] = rep(c(0,1),each = n_reps[nu-j + 1],length=n_combos)
    }
  }else{ mat = matrix(mat,nrow=2,ncol=1)}
  
  ## order configurations for readability ##
  ## rows are first ordered by sum (ascending) 
  ## then first column value (descending), second column value (descending), etc. ##
  
  if(nu == 1){p_configs = mat}else{
	mat.list = list()
	mat.list[[1]] = mat[apply(mat,1,sum)==0,]
	mat.list[[nu+1]] = mat[apply(mat,1,sum)==nu,]
	for(j in 1:(nu-1)){
  	  	tmp.rws = mat[apply(mat,1,sum)==j,]
  		ord.var = apply(tmp.rws,1,function(x) as.numeric(paste(x,collapse="")))
  		mat.list[[j+1]] = tmp.rws[order(ord.var, decreasing=T),]
  		}
  		p_configs = do.call(rbind,mat.list)
  	}  
  
  ############## calculate posterior probability vector ##################
  ## specify number of peptides observed ##
  n_peps = nrow(protein_sig)
  
  ## define matrix of Binomial CDF values ##
  ## first column gives probability of observing proteoform at least as many times as it has been for this data ##
  ## second column gives probability of observing proteoform fewer times than it has been for this data ##
  x_mat = matrix(0, nrow=nu, ncol=2)
  for (j in 1:nu){
    x_mat[j,2] = pbinom(cnt.ord[j]-1, n_peps, pi_probs[j])
  }
  x_mat[,1] = 1 - x_mat[,2]
  
  ## calculate posterior distribution for each proteoform configuration##
  post_prob = rep(1, nrow(p_configs))
  for (j in 1:nrow(p_configs)){
    x = p_configs[j,]
    for(k in 1:nu){
      prior = (pi_probs[k]^x[k])*(1-pi_probs[k])^(1-x[k])
      post_prob[j] = post_prob[j]*prior*x_mat[k,x[k]+1]
    }
  }
  
  post_prob = post_prob/sum(post_prob)
  
  ## store which proteoform configuration has highest posterior probability ##
  id.max = which.max(post_prob)
  
  ## pull maximum configuration ##
  tmp = p_configs[id.max,]
  
  ## determine number of proteoforms and map to protein signatures in observed peptides ##
  ## if an all zero signature pull signatures of counts_ids==1##
  if(sum(tmp)==0){
    peptide_ids = which(counts_ids==1)
    num_proteoforms = 1
  }else{
    num_proteoforms = sum(tmp)
    tid = which(tmp > 0)
    
    peptide_ids = rep(0,length(counts_ids))
    for(q in 1:num_proteoforms){
    peptide_ids[which(counts_ids == tid[q])] = q
    }
  }
  
return(list(post_prob = post_prob, peptide_idx = peptide_ids, unique_sigs = sigs, num_proteoforms = num_proteoforms, proteoform_configs = p_configs))

}
