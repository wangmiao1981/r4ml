#
# (C) Copyright IBM Corp. 2017
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

requireNamespace("SparkR")

setOldClass("r4ml.frame")
setClassUnion("r4ml.frame.OrNull", c("r4ml.frame", "NULL"))

#############################################################################
### r4ml.vector operations
#############################################################################

#' Unlike SparkR's Column objects, r4ml.vector objects can be collected, shown
#' and manipulated similarly to R's vectors. Additionally, all functions available
#' on SparkR Columns are also available for r4ml.vector objects. 
#' 
#' @name r4ml.vector operations
#' @title r4ml.vector operations
#' @rdname r4ml.vector_ops
#' 
#' @examples
##'\dontrun{
## TODO this test case is not working
##' # Load the iris dataset as a r4ml.frame
##' hf <- as.r4ml.frame(iris)
##' 
##' # Advanced nested arithmetic operations
##' avgLength <- (hf$Sepal_Length + hf$Sepal_Width) / 2
##' ones <- sin(avgLength) ^ 2 + cos(avgLength ^ 2)
##' show(ones)
##' 
##' # Character operations
##' lower(substr(hf$Species, 1, 3))
##' 
##' # Recoding columns
##' hf$size <- ifelse(avgLength > 4, "large", "small")
##' str(hf)
##' }
NULL
#' @export
setClass("r4ml.vector", 
         slots = list(hf = "r4ml.frame.OrNull"),
         contains="Column")

setMethod("initialize", "r4ml.vector", function(.Object, jc, hf) {
  .Object@jc <- jc
  
  # Some Column objects don't have any referencing SparkDataFrame. In such case, hf will be NULL.
  if (missing(hf)) {
    hf <- NULL
  }
  .Object@hf <- hf
  .Object
})

#' @export
setMethod("show", signature = "r4ml.vector", definition = function(object) {
  head.df <- head(object, r4ml.env$DEFAULT_SHOW_ROWS)
  
  if (length(head.df) == 0) {
    colname <- SparkR:::callJMethod(object@jc, "toString")
    cat(paste0(colname, "\n"))
    cat(paste0("<Empty column>\n"))
  } else {
    show(head.df)
  }
  if (length(head.df) == r4ml.env$DEFAULT_SHOW_ROWS)  {
    cat(paste0("\b...\nDisplaying up to ", as.character(r4ml.env$DEFAULT_SHOW_ROWS), " elements only.\n"))
  }
})

#' Collects all the elements of a r4ml.vector and coerces them into an R vector.
#'
#' @param x A r4ml.vector
#'
#' @rdname collect
#' @name collect
#' @export
#' @examples
#'\dontrun{
#' hf <- as.r4ml.frame(iris)
#' collect(hf$Sepal_Length)
#' hf$Species 
#' }
setMethod("collect", signature = "r4ml.vector", definition = function(x) {
  if (is.null(x@hf)) {
    character(0)
  } else {
    collect(select(x@hf, x))[, 1]
  }
})

#' @export
setMethod("head", signature = "r4ml.vector", definition = function(x, n=6) {
  if (is.null(x@hf)) {
    collect(x)
  } else {
    head(select(x@hf, x), n)[, 1]
  }
})

#' @export
setMethod("$", signature(x = "r4ml.frame"),
          function(x, name) {
            col <- SparkR:::getColumn(x, name)
            new("r4ml.vector", jc=col@jc, hf=x)
          })


#' Convert the various  data.frame into the r4ml frame.
#'
#' This is the convenient method of converting the r4ml.vector into the SparkR::Column
#'
#' @name as.sparkr.column
#' @param object r4ml.vector
#' @param hv a r4ml.vector
#' @param ... future optional additional arguments to be passed to or from methods
#' @return SparkR::Column
#' @export
#' @examples \dontrun{
#'    iris_hf <- as.r4ml.frame(iris)
#'    pl_mean <- SparkR::mean(as.sparkr.column(iris_hf$Petal_Length))
#'    mval <- SparkR::agg(iris_hf, pl_mean)
#'    mval
#' }
#'    
setGeneric("as.sparkr.column", function(hv, ...) {
  standardGeneric("as.sparkr.column")
})

setMethod("as.sparkr.column",
          signature(hv = "r4ml.vector"),
          function(hv, ...) {
            SparkR::column(hv@jc)
          }
)

#########################
# Clone existing methods
#########################

# Method mean is not defined as a generic in SparkR. Therefore, we must redefine it here
setGeneric("mean")
setMethod("mean",
          signature(x = "Column"),
          function(x) {
            jc <- SparkR:::callJStatic("org.apache.spark.sql.functions", "mean", x@jc)
            column(jc)
          })

# The following code needs to be run in the top level environment. Otherwise dynamically
# created methods will not be part of the R4ML environment

  fnames <- ls("package:SparkR", all.names=T)
  
  # Generic methods appear with an extra .__T__ at the beginning. The code below is to remove that prefix:
  fnames <- sapply(fnames, function(name) {
    x <- if (substring(name, 1, 3) == ".__") {
      substring(
        strsplit(name, ":")[[1]][1],
        7,
        nchar(name) + 1)
    } else {
      name
    }
    x
  })
  
  # Remove duplicates
  fnames <- unique(fnames)
  
  names(fnames) <- NULL
  
  # Only methods with Column arguments
  methodNames <- sapply(fnames, function(x) {
    methods <- findMethods(x, classes=c("Column"))
    if (length(methods) == 0) {
      NA
    } else {
      x
    }
  })
  
  # Filter not needed methods
  methodNames <- methodNames[!is.na(methodNames)]
  names(methodNames) <- NULL
  
  # Remove certain methods that may cause conflicts
  methodNames <- methodNames[-which(methodNames %in% c("length", "show", "head", "collect",
                                                       "select", "withColumn", "ifelse"))]
  
  createR4MLColumnMethod <- function(funName) {
    
    # Get the method with the given name
    method <- findMethods(funName, classes="Column")
    
    # Get argument names and types
    argNames <- method@arguments

    ###############################################
    # Get all argnames from the function definition, not the generic. This is since signatures
    # don't expose all arguments in the method.
    
    f <- method[[1]]@.Data
    
    # Get the declaration from third line of the function, if available.
    declaration <- deparse(f)[3]
    
    # Check if the first line has parameter '...'. If so, declaration is in the third line
    if (length(strsplit(declaration, "<- function")[[1]]) <= 1) {
      declaration <- deparse(f)[1]
    }
    
    # Use string split to get the parameter names
    argsString <- strsplit(declaration, "function")[[1]][2]
    argsString <- strsplit(argsString, "\\(|\\)")[[1]][2]
    funArgNames <- strsplit(argsString, ", ")[[1]]
    ###############################################
    
    #print(funName)
    #show(funArgNames)
    
    argTypes <- strsplit(method@names, "#")[[1]]
    
    # Fill argTypes with ANY for parameters not defined in the signature
    argTypes <- c(argTypes, rep("ANY", length(argNames) - length(argTypes)))
    
    # Build signature
    signature <- argTypes
    names(signature) <- argNames
    signature <- ifelse(signature == "Column", "r4ml.vector", signature)
    {
      if (r4ml.env$VERBOSE) {
        cat("Cloning function", funName, "(", paste(argNames, collapse=", "), ") into R4ML...")
        cat("\n\n\n")
        cat(" OK\n")
      }
      
      # Note function arguments are anonymous, e.g, e2 is not referenced as e2.
      # Solution: use match.call to create variables with the same names as the parameters and assign
      # values passed by the user
      
      functionCode <- 
        paste(paste0("function(", paste(funArgNames, collapse=", "), ") {"),

              # Get the list of arguments that were passed to the function
              '  passedArgNames <- names(as.list(match.call(call=match.call())))',
              # 'browser()',
              # Get which ones are of class r4ml.vector
              '  colArgNames <- passedArgNames[which(unlist(lapply(passedArgNames, function(X123jsd8Abcs81) { class(eval(parse(text=X123jsd8Abcs81))) } )) == "r4ml.vector")]',
              #'  colArgNames <- names(signature[which(signature == "r4ml.vector")])',

              # Get hf from r4ml.vector arguments
              '  eval(parse(text="hf <- " %++% colArgNames[1] %++% "@hf"))',

              # Cast all r4ml.vector parameters to Column so that parent methods can handle them
              '  for (i in 1:length(colArgNames)) {',
              '    eval(parse(text=colArgNames[i] %++% "<- as.sparkr.column(" %++% colArgNames[i] %++% ")"))',
              '  }',

              # Invoke parent method. Since there's a bug in R 3.1 (fixed in 3.2), instead of calling
              # callNextMethod(), we'll directly call the method with the cast parameters. Note quotes
              # are added to the function name to handle functions such as "["
              #'  value <- callNextMethod()',
              #'  
              #'  browser()', 
              'argsString <- "(" %++% paste(passedArgNames[-1], collapse=", ") %++% ")"',
              paste0('  callString <- "\'', funName, '\'" %++% argsString'),
              #' print(callString)',
              '  value <-  eval(parse(text=callString))',

              # If the result is a Column object, cast it back to r4ml.vector
              '  if (class(value) == "Column") {',
              #'    args <- as.list(match.call())',
              #'    colArg <- eval(args[[colArgNames]])',
              '    return(new("r4ml.vector", jc=value@jc, hf=hf))',
              '  }',
              '  return(value)',
              "}",
              sep="\n")
      #print(signature)
      #cat("\n")
      #cat(functionCode)
      #cat("\n\n\n")
      #browser()
      return(list(functionCode, funName, signature))
    }
  }
  
  # Create all methods
  for (name in methodNames) {
    # disable it for now. In future, we will re-evaluate the functionality and see after bug fixes 
    # enable it
    next
    args <- createR4MLColumnMethod(name)
    if (length(args) > 0) {
      functionCode <- args[[1]]
      funName <- args[[2]]
      signature <- args[[3]]
      fun <- eval(parse(text=functionCode))
      setMethod(funName, 
                signature,
                fun)
    }
  }
  cat("\n", length(methodNames), "R4ML methods were created from SparkR.")

setGeneric("ifelse")
setMethod("ifelse", signature(test = "r4ml.vector", yes = "ANY", no = "ANY"),
  function(test, yes, no) {
    hf <- test@hf
    test <- test@jc
    yes <- if (inherits(yes, "Column")) { yes@jc } else { yes }
    no <- if (inherits(no, "Column")) { no@jc } else { no }
    jc <- SparkR:::callJMethod(
            SparkR:::callJStatic("org.apache.spark.sql.functions", "when", test, yes),
            "otherwise", no
          )
    result <- new("r4ml.vector", jc, hf)
    result
})

setMethod("str",
  signature(object = "r4ml.vector"),
  function(object) {
    cat("'r4ml.vector'\n")
    out <- capture.output(str(select(object@hf, object)))
    cat(out[2] %++% "\n")
})
