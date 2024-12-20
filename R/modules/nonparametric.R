nonparametricUI <- function(id) {
  ns <- NS(id)

  tagList(
    layout_columns(
      height = "100%",
      plotlyOutput(ns("distribution"))
    ),
    layout_columns(
      verbatimTextOutput(ns("hypothesis")),
      verbatimTextOutput(ns("stats"))
    )
  )
}

nonparametricServer <- function(id, control) {
  moduleServer(id, function(input, output, session) {
    sud <- session$userData

    output$distribution <-  renderPlotly({
      sam <- sud$sampleData()
      test <- conduct_wilcox_test(sam$x1, sam$x2, control)

      if (is.null(sam$x2)) {
        W <- test$statistic
        mu <- control$n*(control$n + 1)/4
        s2 <- control$n*(control$n + 1)*(2*control$n + 1)/24
      } else {
        if (control$paired) {
          d <- sam$x1 - sam$x2
          d_nonzero <- d[d != 0]
          n <- length(d_nonzero)
          ranks <- rank(abs(d_nonzero))
          signed_ranks <- ranks * sign(d_nonzero)
          W <- sum(signed_ranks[signed_ranks > 0])
          mu <- control$n * (control$n + 1) / 4
          s2 <- control$n * (control$n + 1) * (2 * control$n + 1) / 24
        } else {
          W <- test$statistic + control$n * (control$n + 1) / 2
          mu <- control$n*(2*control$n + 1)/2
          s2 <- control$n*control$n*(2*control$n + 1)/12
        }
      }
      test.stat <- (W - mu) / sqrt(s2)

      dH0 <- Normal$new()
      p.test.stat <- dH0$pdf(test.stat)
      abs.test.stat <- abs(test.stat)
      # Pravá strana H0
      xH0r <- seq(from = abs.test.stat,
                  to = max(abs.test.stat, dH0$quantile(1 - (1/1000))),
                  by = 0.01)
      yH0r <- dH0$pdf(xH0r)
      # Levá strana HO
      xH0l <- seq(from = -abs.test.stat,
                  to = min(-abs.test.stat, dH0$quantile(1/1000)),
                  by = -0.01)
      yH0l <- dH0$pdf(xH0l)
      # Data pro H0
      xy <- get_xy(d = dH0)
      plot <-
        plot_ly(type = 'scatter', mode = 'lines') |>
        add_trace(x = ~xy$x, y = ~xy$y, name = xy$n,
                  hoverinfo = 'text',
                  text = ~ glue("{xy$n}<br>",
                                "f({xy$x}) = {xy$y}")) |>
        add_trace(x = ~test.stat, y = ~p.test.stat, mode = "marker",
                  hoverinfo = 'text',
                  text = ~ glue("T={test.stat}")) |>
        add_trace(x = ~xH0r, y = ~yH0r, fill = "tozeroy", fillcolor = '#ff4e4e',
                  hoverinfo = 'text',
                  hoveron = 'fills',
                  text = ~ glue("p-value: {test$p.value}")) |>
        add_trace(x = ~xH0l, y = ~yH0l, fill = "tozeroy", fillcolor = '#ff4e4e',
                  hoverinfo = 'text',
                  hoveron = 'fills',
                  text = ~ glue("p-value: {test$p.value}")) |>
        layout(
          title = test$method,
          xaxis = list(
            title = "",
            showgrid = FALSE,
            zeroline = FALSE
          ),
          yaxis = list(
            title = paste("Hustota pro", xy$n)
          ),
          showlegend = FALSE
        )

      plot
    }) |>
      bindEvent(control$go)

    output$hypothesis <- renderPrint({
      sam <- sud$sampleData()
      test <- conduct_wilcox_test(sam$x1, sam$x2, control)
      if (is.null(sam$x2)) {
        W <- test$statistic
        mu <- control$n*(control$n + 1)/4
        s2 <- control$n*(control$n + 1)*(2*control$n + 1)/24
      } else {
        if (control$paired) {
          d <- sam$x1 - sam$x2
          d_nonzero <- d[d != 0]
          n <- length(d_nonzero)
          ranks <- rank(abs(d_nonzero))
          signed_ranks <- ranks * sign(d_nonzero)
          W <- sum(signed_ranks[signed_ranks > 0])
          mu <- control$n * (control$n + 1) / 4
          s2 <- control$n * (control$n + 1) * (2 * control$n + 1) / 24
        } else {
          W <- test$statistic + control$n * (control$n + 1) / 2
          mu <- control$n*(2*control$n + 1)/2
          s2 <- control$n*control$n*(2*control$n + 1)/12
        }
      }
      test.stat <- (W - mu) / sqrt(s2)

      glue(
        "H0: mu = {control$H0}\n",
        "W: {W} (z: {test.stat})\n",
        "p-val.: {test$p.value}\n"
      )
    }) |>
      bindEvent(control$go)

    output$stats <- renderPrint({
      pop <- sud$population()
      # t-test
      errorI <- sapply(
        X = seq_len(control$K),
        FUN = \(i) {
          set.seed(control$seed + i)
          s1 <- pop$x1$rand(control$n)
          mu <- pop$x1$mean()
          s2 <- NULL
          if (!is.null(pop$x2)) {
            s2 <- pop$x2$rand(control$n)
            mu <- mu - pop$x2$mean()
          }

          conduct_wilcox_test(s1, s2, control)$p.value <= control$alpha
        }
      ) |> mean()

      errorII <- sapply(
        X = seq_len(control$K),
        FUN = \(i) {
          set.seed(control$seed + i)
          s1 <- pop$x1$rand(control$n)
          s2 <- NULL
          if (!is.null(pop$x2)) {
            s2 <- pop$x2$rand(control$n)
          }

          conduct_wilcox_test(s1, s2, control, use_h0 = FALSE)$p.value >= control$alpha
        }
      ) |> mean()

      glue(
        "Chyba I. typu: {errorI}\n",
        "Chyba II. typu: {errorII}\n",
        "Síla testu: {1 - errorII}\n",
      )
    }) |>
      bindEvent(control$go)
  })
}
