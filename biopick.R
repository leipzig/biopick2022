library(BatchGetSymbols)
library(dplyr)
library(lubridate)
library(ggplot2)
library(ggthemes)

biopick <- read.table("Biopick2022-wk1.csv", header = TRUE)
pickFreq <- as.data.frame(sort(table(biopick), decreasing = TRUE))
names(pickFreq) <- c("ticker", "freq")
batchres <- BatchGetSymbols(
  pickFreq$ticker,
  first.date = "2021-12-31",
  last.date = lubridate::today()+1,
  thresh.bad.data = 0.75,
  bench.ticker = "^GSPC",
  type.return = "arit",
  freq.data = "daily",
  how.to.aggregate = "last",
  do.complete.data = FALSE,
  do.fill.missing.prices = TRUE,
  do.cache = TRUE,
  cache.folder = file.path(tempdir(), "BGS_Cache"),
  do.parallel = FALSE,
  be.quiet = FALSE
)

prices <- batchres$df.tickers %>%
  merge(pickFreq) %>%
  mutate(datething = lubridate::as_datetime(ref.date)) %>%
  group_by(ticker) %>%
  dplyr::mutate(nrml_price = price.close * 100 / first(price.close))

ggplot(prices %>% filter(freq > 10), aes(ref.date, nrml_price)) + geom_line(aes(color =
                                                                                  ticker, size = freq))

lastdate <- max(prices$datething)
results <-
  prices %>% dplyr::filter(datething == lastdate) %>% dplyr::select(nrml_price, freq)

results %>% arrange(-nrml_price) %>% knitr::kable() -> mktable


myplot<-ggplot(results, aes(freq, nrml_price)) +
  geom_point(aes(colour=nrml_price)) +
  scale_colour_gradient2(
    low = "red",
    high = "green",
    midpoint = 100
  ) +
  geom_text(
    data = subset(results, freq > 10 |
                    nrml_price > 110),
    aes(freq, nrml_price, label = paste0(ticker)),
    check_overlap = FALSE,
    position = position_jitter(width = 2, height = 2),
    hjust = 1.2
  ) +
  geom_text(
    data = subset(results, nrml_price < 50),
    aes(freq, nrml_price, label = paste0(ticker)),
    check_overlap = FALSE,
    position = position_jitter(width = 2, height = 2),
    vjust = 1.2
  ) +
  scale_y_continuous(breaks = seq(0, 1000, 20)) + 
  xlim(-5, 70)+xlab("Number of Picks")+ylab(paste(Sys.Date(),"percent of price on 01/03/2022"))
ggsave(filename = "biopicks.png",plot = myplot)

#poor man's rmd
write(c("# biopick2022","Percent of original price and number of entrants for each ticket for [Biopick2022](https://twitter.com/hashtag/Biopick2022)"),file = "README.md",append=FALSE)
write(mktable,file = "README.md",append=TRUE)
write("![retvspicks](biopicks.png?raw=true)",file = "README.md",append=TRUE)
