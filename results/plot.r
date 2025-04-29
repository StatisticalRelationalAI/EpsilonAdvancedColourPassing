library(ggplot2)
library(dplyr)
library(patchwork)
library(stringr)
library(tikzDevice)

use_tikz = TRUE

if (use_tikz) {
  lpos = c(0.13, 0.85)
  lpos_offline = c(0.44, 1.0)
} else {
  lpos = c(0.12, 0.9)
  lpos_offline = c(0.32, 0.95)
}

kldiv_main = "results.csv"
kldiv_app  = "results.csv"
quots_main = "results-prepared-main.csv"
quots_app  = "results-prepared-main.csv"
times_main = "results_stats-prepared-main.csv"
times_app  = "results_stats-prepared-appendix.csv"
offline    = "results_stats-offline-prepared-all.csv"

data_times_main = read.csv(file = times_main, sep=",", dec=".")
data_kldiv_main = read.csv(file = kldiv_main, sep=",", dec=".")
data_quots_main = read.csv(file = quots_main, sep=",", dec=".")

data_times_main["algo"][data_times_main["algo"] == "EACP"] = "$\\varepsilon$-ACP"
data_times_main = rename(data_times_main, "Algorithm" = "algo")
data_kldiv_main = filter(data_kldiv_main, algo == "EACP")
data_kldiv_main = filter(data_kldiv_main, kl_divergence != "NaN")
data_kldiv_main = filter(data_kldiv_main, kl_divergence != "timeout")
data_kldiv_main$kl_divergence = as.numeric(as.character(data_kldiv_main$kl_divergence))
data_kldiv_main = filter(data_kldiv_main, kl_divergence >= 0)

data_times_main = filter(data_times_main, d <= 128)
data_kldiv_main = filter(data_kldiv_main, d <= 128)
data_quots_main = filter(data_quots_main, d <= 128)

if (use_tikz) {
  tikz("plot-times-avg.tex", standAlone = FALSE, width = 3.3, height = 1.6)
} else {
  pdf(file = "plot-times-avg.pdf", height = 2.4)
}

p1 <- ggplot(data_times_main, aes(x=d, y=mean_t, group=Algorithm, color=Algorithm)) +
  geom_line(aes(group=Algorithm, linetype=Algorithm, color=Algorithm)) +
  geom_point(aes(group=Algorithm, shape=Algorithm, color=Algorithm)) +
  #geom_ribbon(aes(y=mean_t, ymin=mean_t-std, ymax=mean_t+std, fill=Algorithm), alpha=0.2, colour=NA) +
  xlab("domain size") +
  ylab("time (ms)") +
  scale_y_log10() +
  theme_classic() +
  theme(
    axis.line.x = element_line(arrow = grid::arrow(length = unit(0.1, "cm"))),
    axis.line.y = element_line(arrow = grid::arrow(length = unit(0.1, "cm"))),
    axis.title = element_text(size=10),
    legend.position = lpos,
    legend.title = element_blank(),
    legend.text = element_text(size=8),
    legend.background = element_rect(fill = NA),
    legend.spacing.y = unit(0, 'mm')
  ) +
  guides(fill = "none") +
  scale_shape_manual(values=c(19, 15))+
  scale_color_manual(values=c(
    rgb(247,192,26, maxColorValue=255),
    rgb(78,155,133, maxColorValue=255)
  )) +
  scale_fill_manual(values=c(
    rgb(247,192,26, maxColorValue=255),
    rgb(78,155,133, maxColorValue=255)
  ))

p1
dev.off()

# if (use_tikz) {
#   tikz("plot-kldiv-avg.tex", standAlone = FALSE, width = 3.3, height = 1.6)
# } else {
#   pdf(file = "plot-kldiv-avg.pdf", height = 2.4)
# }

# p2 <- ggplot(data_kldiv_main, aes(x=as.factor(d), y=kl_divergence, group=as.factor(d))) +
#   geom_boxplot(color=rgb(78,155,133, maxColorValue=255), fill=rgb(78,155,133, maxColorValue=255), alpha=0.2) +
#   xlab("domain size") +
#   ylab("KLD") +
#   theme_classic() +
#   theme(
#     axis.line.x = element_line(arrow = grid::arrow(length = unit(0.1, "cm"))),
#     axis.line.y = element_line(arrow = grid::arrow(length = unit(0.1, "cm"))),
#     axis.title = element_text(size=10),
#     legend.position = lpos,
#     legend.title = element_blank(),
#     legend.text = element_text(size=8),
#     legend.background = element_rect(fill = NA),
#     legend.spacing.y = unit(0, 'mm')
#   ) +
#   coord_cartesian(ylim = c(0, 5e-7)) +
#   guides(fill = "none")
# 
# p2
# dev.off()

if (use_tikz) {
  tikz("plot-quots-avg.tex", standAlone = FALSE, width = 3.3, height = 1.6)
} else {
  pdf(file = "plot-quots-avg.pdf", height = 2.4)
}

p3 <- ggplot(data_quots_main, aes(x=as.factor(d), y=quotient, group=as.factor(d))) +
  geom_boxplot(color=rgb(78,155,133, maxColorValue=255), fill=rgb(78,155,133, maxColorValue=255), alpha=0.2) +
  xlab("domain size") +
  ylab("$p' \\mathbin{/} p$") +
  theme_classic() +
  theme(
    axis.line.x = element_line(arrow = grid::arrow(length = unit(0.1, "cm"))),
    axis.line.y = element_line(arrow = grid::arrow(length = unit(0.1, "cm"))),
    axis.title = element_text(size=10),
    legend.position = lpos,
    legend.title = element_blank(),
    legend.text = element_text(size=8),
    legend.background = element_rect(fill = NA),
    legend.spacing.y = unit(0, 'mm')
  ) +
  coord_cartesian(ylim = c(1 - 2e-3, 1 + 2e-3)) +
  guides(fill = "none")

p3
dev.off()


data_times_app = read.csv(file = times_app, sep=",", dec=".")
data_kldiv_app = read.csv(file = kldiv_app, sep=",", dec=".")
data_quots_app = read.csv(file = quots_app, sep=",", dec=".")

data_times_app["algo"][data_times_app["algo"] == "EACP"] = "$\\varepsilon$-ACP"
data_times_app = rename(data_times_app, "Algorithm" = "algo")
data_kldiv_app = filter(data_kldiv_app, algo == "EACP")
data_kldiv_app = filter(data_kldiv_app, kl_divergence != "NaN")
data_kldiv_app = filter(data_kldiv_app, kl_divergence != "timeout")
data_kldiv_app$kl_divergence = as.numeric(as.character(data_kldiv_app$kl_divergence))
data_kldiv_app = filter(data_kldiv_app, kl_divergence >= 0)

data_times_app = filter(data_times_app, d <= 128)
data_kldiv_app = filter(data_kldiv_app, d <= 128)
data_quots_app = filter(data_quots_app, d <= 128)

for (pval in c(0.1, 0.3, 0.5, 0.7, 0.9, 1.0)) {
  for (epsval in c(0.001, 0.1)) { # c(0.001, 0.01, 0.1)
    # data_times_app_filtered = filter(data_times_app, p == pval)
    # data_times_app_filtered = filter(data_times_app_filtered, epsilon == epsval)

    # if (nrow(data_times_app_filtered) == 0) next

    # if (use_tikz) {
    #   tikz(paste("plot-times-p=", pval, "-eps=", epsval, ".tex", sep=""), standAlone = FALSE, width = 3.3, height = 1.6)
    # } else {
    #   pdf(file = paste("plot-times-p=", pval, "-eps=", epsval, ".pdf", sep=""), height = 2.4)
    # }

    # p1 <- ggplot(data_times_app_filtered, aes(x=d, y=mean_t, group=Algorithm, color=Algorithm)) +
    #   geom_line(aes(group=Algorithm, linetype=Algorithm, color=Algorithm)) +
    #   geom_point(aes(group=Algorithm, shape=Algorithm, color=Algorithm)) +
    #   xlab("domain size") +
    #   ylab("time (ms)") +
    #   scale_y_log10() +
    #   theme_classic() +
    #   theme(
    #     axis.line.x = element_line(arrow = grid::arrow(length = unit(0.1, "cm"))),
    #     axis.line.y = element_line(arrow = grid::arrow(length = unit(0.1, "cm"))),
    #     axis.title = element_text(size=10),
    #     legend.position = lpos,
    #     legend.title = element_blank(),
    #     legend.text = element_text(size=8),
    #     legend.background = element_rect(fill = NA),
    #     legend.spacing.y = unit(0, 'mm')
    #   ) +
    #   guides(fill = "none") +
    #   scale_shape_manual(values=c(19, 15))+
    #   scale_color_manual(values=c(
    #     rgb(247,192,26, maxColorValue=255),
    #     rgb(78,155,133, maxColorValue=255)
    #   )) +
    #   scale_fill_manual(values=c(
    #     rgb(247,192,26, maxColorValue=255),
    #     rgb(78,155,133, maxColorValue=255)
    #   ))

    # print(p1)
    # dev.off()


    # data_kldiv_app_filtered = filter(data_kldiv_app, p == pval)
    # data_kldiv_app_filtered = filter(data_kldiv_app_filtered, epsilon == epsval)
    # 
    # if (nrow(data_kldiv_app_filtered) == 0) next
    # 
    # if (use_tikz) {
    #   tikz(paste("plot-kldiv-p=", pval, "-eps=", epsval, ".tex", sep=""), standAlone = FALSE, width = 3.3, height = 1.6)
    # } else {
    #   pdf(file = paste("plot-kldiv-p=", pval, "-eps=", epsval, ".pdf", sep=""), height = 2.4)
    # }
    # 
    # y_limit = if (epsval == 0.1) 1e-5 else 3e-9
    # 
    # p2 <- ggplot(data_kldiv_app_filtered, aes(x=as.factor(d), y=kl_divergence, group=as.factor(d))) +
    #   geom_boxplot(color=rgb(78,155,133, maxColorValue=255), fill=rgb(78,155,133, maxColorValue=255), alpha=0.2) +
    #   xlab("domain size") +
    #   ylab("$P_{M'}(r \\mid \\boldsymbol e) \\mathbin{/} P_M(r \\mid \\boldsymbol e)$") +
    #   theme_classic() +
    #   theme(
    #     axis.line.x = element_line(arrow = grid::arrow(length = unit(0.1, "cm"))),
    #     axis.line.y = element_line(arrow = grid::arrow(length = unit(0.1, "cm"))),
    #     axis.title = element_text(size=10),
    #     legend.position = lpos,
    #     legend.title = element_blank(),
    #     legend.text = element_text(size=8),
    #     legend.background = element_rect(fill = NA),
    #     legend.spacing.y = unit(0, 'mm')
    #   ) +
    #   coord_cartesian(ylim = c(0, y_limit)) +
    #   guides(fill = "none")
    # 
    #   print(p2)
    #   dev.off()

    data_quots_app_filtered = filter(data_quots_app, p == pval)
    data_quots_app_filtered = filter(data_quots_app_filtered, eps == epsval)

    if (nrow(data_quots_app_filtered) == 0) next

    if (use_tikz) {
      tikz(paste("plot-quots-p=", pval, "-eps=", epsval, ".tex", sep=""), standAlone = FALSE, width = 3.3, height = 1.6)
    } else {
      pdf(file = paste("plot-quots-p=", pval, "-eps=", epsval, ".pdf", sep=""), height = 2.4)
    }

    y_min_limit = if (epsval == 0.1) 1 - 3e-2 else 1 - 3e-4
    y_max_limit = if (epsval == 0.1) 1 + 3e-2 else 1 + 3e-4

    p3 <- ggplot(data_quots_app_filtered, aes(x=as.factor(d), y=quotient, group=as.factor(d))) +
      geom_boxplot(color=rgb(78,155,133, maxColorValue=255), fill=rgb(78,155,133, maxColorValue=255), alpha=0.2) +
      xlab("domain size") +
      ylab("$p' \\mathbin{/} p$") +
      theme_classic() +
      theme(
        axis.line.x = element_line(arrow = grid::arrow(length = unit(0.1, "cm"))),
        axis.line.y = element_line(arrow = grid::arrow(length = unit(0.1, "cm"))),
        axis.title = element_text(size=10),
        legend.position = lpos,
        legend.title = element_blank(),
        legend.text = element_text(size=8),
        legend.background = element_rect(fill = NA),
        legend.spacing.y = unit(0, 'mm')
      ) +
      coord_cartesian(ylim = c(y_min_limit, y_max_limit)) +
      guides(fill = "none")

    print(p3)
    dev.off()
  }
}


data_offline = read.csv(file = offline, sep=",", dec=".")
data_offline = filter(data_offline, d <= 128)

for (pval in c(0.1, 0.3, 0.5, 0.7, 0.9, 1.0)) {
  data_offline_filtered = filter(data_offline, p == pval)
 # data_offline_filtered$alpha = sapply(data_offline_filtered$alpha, function(x) max(x, 0))

  if (nrow(data_offline_filtered) == 0) next

  if (use_tikz) {
    tikz(paste("plot-offline-p=", pval, ".tex", sep=""), standAlone = FALSE, width = 3.3, height = 1.6)
  } else {
    pdf(paste("plot-offline-p=", pval, ".pdf", sep=""), height = 2.4)
  }

  p <- ggplot(data_offline_filtered, aes(x=as.factor(d), y=alpha, color=as.factor(eps))) +
    geom_boxplot(alpha=0.2) +
    xlab("domain size") +
    ylab("$\\alpha$") +
    theme_classic() +
    theme(
      axis.line.x = element_line(arrow = grid::arrow(length = unit(0.1, "cm"))),
      axis.line.y = element_line(arrow = grid::arrow(length = unit(0.1, "cm"))),
      axis.title = element_text(size=10),
      legend.position = lpos_offline,
      legend.direction = "horizontal",
      legend.title = element_blank(),
      legend.text = element_text(size=8),
      legend.background = element_rect(fill = NA),
      legend.spacing.y = unit(0, 'mm')
    ) +
    scale_y_log10(labels = function(x) format(x, scientific = FALSE)) +
    guides(fill = "none") +
    scale_color_manual(
      values = c(
        rgb(247,192,26, maxColorValue=255),
        rgb(37,122,164, maxColorValue=255),
        rgb(78,155,133, maxColorValue=255)
      ),
      breaks = c("0.001", "0.01", "0.1"),
      labels = c("$\\varepsilon=0.001$", "$\\varepsilon=0.01$", "$\\varepsilon=0.1$")
    )

  print(p)

  dev.off()
}

