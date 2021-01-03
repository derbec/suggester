/// Suggester works by tokenising both suggestions and input using a Term Mapping
/// and finding partial matches between them via prefix searching.
///
/// Choice of Term Mapping determines how Suggester matches to a particular dataset.
///
/// A Term Mapping that generates more terms will result in higher memory usage.
library term_mapping;

export 'src/term_mapping.dart';
