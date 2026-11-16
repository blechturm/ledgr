# Cut 20 seven-shape walk, shape 7 (scalar writes into an environment-held
# vector): does a buffer bound in the hashed body environment copy on a
# by-index write, from the body's top level or from a stage closure's <<-?
# The plain function frame is the control. tracemem() reports each copy.
#
#   Rscript dev/lean_core/parity/cut20_shape7.R [out.txt]

args <- commandArgs(TRUE)
plain <- function(n, control = FALSE) {
  buf <- numeric(n)
  if (control) keep <- buf                       # a second reference: the first write must copy
  lst <- list(a = numeric(n))
  copies <- character()
  tracemem(buf); tracemem(lst$a)
  log <- utils::capture.output({
    for (i in 1:5) buf[[i]] <- i                # top-level write
    stage <- function(i) { buf[[i]] <<- i; lst$a[[i]] <<- i }   # a stage closure's writes
    for (i in 6:10) stage(i)
  }, type = "output")
  untracemem(buf); untracemem(lst$a)
  c(copies = sum(grepl("tracemem", log)), total = sum(buf) + sum(lst$a))
}
code <- compiler::compile(body(plain), env = environment(plain))
hashed <- function(n, control = FALSE) eval(code, new.env(hash = TRUE, parent = environment()))
res <- rbind(plain = compiler::cmpfun(plain)(1e6), hashed = compiler::cmpfun(hashed)(1e6),
             plain_control = compiler::cmpfun(plain)(1e6, TRUE), hashed_control = compiler::cmpfun(hashed)(1e6, TRUE))
lines <- c("Copies reported by tracemem() over 5 top-level and 5 closure writes into a 1e6 buffer",
           "(control rows: a second reference to the buffer exists, so the first write must copy):",
           utils::capture.output(print(res)))
if (length(args)) writeLines(lines, args[[1L]])
cat(lines, sep = "\n")
