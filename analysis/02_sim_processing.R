library(tidyverse)

# --------------------------------------------------------
# 1. Processing raw simulation outputs
# --------------------------------------------------------

# read in parameter set list
X <- readRDS(here::here("analysis/data-derived/sims/X.rds"))
parms <- readRDS(here::here("analysis/data-derived/lhs_sample.rds")) %>%
  filter(linked == 0)

# get file dir
res_dir <- here::here("analysis/data-derived/sims/")

# function to grab key summaries
get_df <- function(x){
  cases <- sum(x$succesfull_treatments) + sum(x$unsuccesful_treatments_lpf) + x$not_treated

  # epi outcomes
  df <- data.frame("cases" = cases*12,
                   "prev" = x$pcr_prev,
                   "micro210" = x$micro_2_10,
                   "tf" = x$overall_treatment_failure,
                   "lpf" = sum(x$unsuccesful_treatments_lpf*12),
                   "lcf" = sum(x$unsuccesful_treatments_lpf*12*0.2))
  df$all_cases <- df$cases + df$lcf
  df$deaths <- df$all_cases * 0.003
  df$lcf_deaths <- df$lcf * 0.003

  # allele frequencies
  all_df <- as.data.frame(t(x$af))
  names(all_df) <- paste0("a_",seq_along(x$af))
  df <- cbind(df, all_df)

  # lineage frequencies
  # lin_df <- as.data.frame(t(as.numeric(x$lineage))/sum(x$lineage))
  # names(lin_df) <- paste0("l_", names(x$lineage))

  return(df)
}

# function to calculate selection coefficients
# higher lower bound to filter mutation rates out
get_s <- function(xin, tin, upp = 0.975, low = 0.05){

# remove 0 and 1 values
rmpos <- which(xin < upp & xin > low)
while(length(rmpos) < 96) {
  upp <- 1 - ((1-upp)*0.99)
  low <- low * 0.99
  rmpos <- which(xin < upp & xin > low)
}

x <- xin[rmpos]
t <- tin[rmpos]

# at least 8 years still remaining of data for calculating selection
if(length(x) > 95) {
  # selection coefficient / year
  s <- lm(log(x / (1-x)) ~ t)$coefficients[2]
} else {
  s <- NA
}

return(s)
}

# create res list
res_list <- vector("list", nrow(parms))

for(i in sort(as.integer(gsub("r_(\\d*)\\.rds", "\\1", list.files(here::here("analysis/data-derived/sims/")))))) {

  message(i)
  res_i <- readRDS(paste0(res_dir, "r_", i, ".rds"))

  res <- lapply(seq_along(res_i), function(ii){

    df <- res_i[[ii]]

    # get raw data
    df <- head(df, -1) %>%
      lapply(get_df) %>%
      do.call(rbind,.) %>%
      mutate(t = seq(30, n()*30, 30)/365) %>%
      as_tibble

    # filter to after selection was implemented
    df2 <- df %>% filter(t < 20.05 & t > 18.05)
    res <- data.frame("pcr" = mean(df2$prev, na.rm = TRUE),
                      "micro210" = mean(df2$micro210, na.rm = TRUE))

    # filter to after selection was implemented
    df <- df %>% filter(t > 20.05)

    # Calculate selection
    res$s_a_1 <- get_s(df$a_1, df$t)
    res$s_a_2 <- get_s(df$a_2, df$t)
    res$s_a_3 <- get_s(df$a_3, df$t)
    res$s_a_4 <- get_s(df$a_4, df$t)
    res$s_a_5 <- get_s(df$a_5, df$t)
    res$s_a_6 <- get_s(df$a_6, df$t)

    # reorder
    res <- res %>% select(starts_with("s_a"), everything())

    # add in simulation parms
    res$rep <- ii
    res <- cbind(res, parms[i,])

  }) %>% do.call(rbind, .)

  rownames(res) <- NULL
  res_list[[i]] <- res


}

saveRDS(res_list, here::here("analysis/data-derived/model_s.rds"))


