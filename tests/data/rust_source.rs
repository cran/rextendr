use extendr_api::prelude::*;

#[extendr]
pub fn test_method() -> i32 { 42i32 }

extendr_module! {
    mod test_module;
    fn test_method;
}