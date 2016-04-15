#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
library (HydraR)

context("Testing hydrar.frame\n")

# test hydra c'tor
#
test_that("hydrar.frame", {
  warning("test construction of hydrar.frame is not implemented yet")
  # test creation from SparkR dataframe

})

# test is.hydrar.numeric
test_that("is.hydrar.numeric", {
  warning("test is.hydrar.numeric is not implemented yet")
  # test that it return true for numeric hydrar.frame

  # test that it returns false for non numeric hydrar.frame

})

# test as.hydrar.frame for R dataframe
test_that("as.hydrar.frame", {
  warning("test as.hydrar.frame from R data.frame is not implemented yet")
  # test that we can convert from data frame from R data.frame
})


# test as.hydrar.frame for SparkR DataFrame
test_that("as.hydrar.frame", {
  warning("test as.hydrar.frame from SparkR DataFrame is not implemented yet")
  # test that we can convert from SparkR DataFrame
})