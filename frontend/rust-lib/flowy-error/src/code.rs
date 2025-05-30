use serde_repr::*;
use thiserror::Error;

use flowy_derive::ProtoBuf_Enum;

#[derive(
  Debug, Default, Clone, PartialEq, Eq, Error, Serialize_repr, Deserialize_repr, ProtoBuf_Enum,
)]
#[repr(u8)]
pub enum ErrorCode {
  #[default]
  #[error("Internal error")]
  Internal = 0,

  #[error("Unauthorized user")]
  UserUnauthorized = 2,

  #[error("Record not found")]
  RecordNotFound = 3,

  #[error("User id is empty")]
  UserIdIsEmpty = 4,

  #[error("Workspace name can not be empty or whitespace")]
  WorkspaceNameInvalid = 5,

  #[error("Workspace desc is invalid")]
  WorkspaceDescTooLong = 8,

  #[error("Workspace description too long")]
  WorkspaceNameTooLong = 9,

  #[error("Can't load the workspace data")]
  WorkspaceInitializeError = 6,

  #[error("View name can not be empty or whitespace")]
  ViewNameInvalid = 12,

  #[error("Thumbnail of the view is invalid")]
  ViewThumbnailInvalid = 13,

  #[error("View id can not be empty or whitespace")]
  ViewIdIsInvalid = 14,

  #[error("View data is invalid")]
  ViewDataInvalid = 16,

  #[error("View name too long")]
  ViewNameTooLong = 17,

  #[error("Email can not be empty or whitespace")]
  EmailIsEmpty = 19,

  #[error("Email format is not valid")]
  EmailFormatInvalid = 20,

  #[error("Email already exists")]
  EmailAlreadyExists = 21,

  #[error("Password can not be empty or whitespace")]
  PasswordIsEmpty = 22,

  #[error("Password format too long")]
  PasswordTooLong = 23,

  #[error("Password contains forbidden characters.")]
  PasswordContainsForbidCharacters = 24,

  #[error(
    "Password should contain a minimum of 6 characters with 1 special 1 letter and 1 numeric"
  )]
  PasswordFormatInvalid = 25,

  #[error("Password not match")]
  PasswordNotMatch = 26,

  #[error("User name is too long")]
  UserNameTooLong = 27,

  #[error("User name contain forbidden characters")]
  UserNameContainForbiddenCharacters = 28,

  #[error("User name can not be empty or whitespace")]
  UserNameIsEmpty = 29,

  #[error("user id is empty or whitespace")]
  UserIdInvalid = 30,

  #[error("Text is too long")]
  TextTooLong = 32,

  #[error("Database id is empty")]
  DatabaseIdIsEmpty = 33,

  #[error("Grid view id is empty")]
  DatabaseViewIdIsEmpty = 34,

  #[error("Grid block id is empty")]
  BlockIdIsEmpty = 35,

  #[error("Row id is empty")]
  RowIdIsEmpty = 36,

  #[error("Select option id is empty")]
  OptionIdIsEmpty = 37,

  #[error("Field id is empty")]
  FieldIdIsEmpty = 38,

  #[error("Field doesn't exist")]
  FieldDoesNotExist = 39,

  #[error("The name of the option should not be empty")]
  SelectOptionNameIsEmpty = 40,

  #[error("Field not exists")]
  FieldNotExists = 41,

  #[error("The operation in this field is invalid")]
  FieldInvalidOperation = 42,

  #[error("Filter id is empty")]
  FilterIdIsEmpty = 43,

  #[error("Field is not exist")]
  FieldRecordNotFound = 44,

  #[error("Field's type-option data should not be empty")]
  TypeOptionDataIsEmpty = 45,

  #[error("Group id is empty")]
  GroupIdIsEmpty = 46,

  #[error("Invalid date time format")]
  InvalidDateTimeFormat = 48,

  #[error("Invalid params")]
  InvalidParams = 49,

  #[error("Serde")]
  Serde = 50,

  #[error("Protobuf serde")]
  ProtobufSerde = 51,

  #[error("Out of bounds")]
  OutOfBounds = 52,

  #[error("Sort id is empty")]
  SortIdIsEmpty = 53,

  #[error("Connect refused")]
  ConnectRefused = 54,

  #[error("Connection timeout")]
  ConnectTimeout = 55,

  #[error("Connection closed")]
  ConnectClose = 56,

  #[error("Connection canceled")]
  ConnectCancel = 57,

  #[error("Sql error")]
  SqlError = 58,

  #[error("Network error")]
  NetworkError = 59,

  #[error("The content should not be empty")]
  UnexpectedEmpty = 60,

  #[error("Only the date type can be used in calendar")]
  UnexpectedCalendarFieldType = 61,

  #[error("Document Data Invalid")]
  DocumentDataInvalid = 62,

  #[error("Unsupported auth type")]
  UnsupportedAuthType = 63,

  #[error("Invalid auth configuration")]
  InvalidAuthConfig = 64,

  #[error("Missing auth field")]
  MissingAuthField = 65,

  #[error("Rocksdb IO error")]
  RocksdbIOError = 66,

  #[error("Document id is empty")]
  DocumentIdIsEmpty = 67,

  #[error("Apply actions is empty")]
  ApplyActionsIsEmpty = 68,

  #[error("Connect postgres database failed")]
  PgConnectError = 69,

  #[error("Postgres database error")]
  PgDatabaseError = 70,

  #[error("Postgres transaction error")]
  PgTransactionError = 71,

  #[error("Enable data sync")]
  DataSyncRequired = 72,

  #[error("Conflict")]
  Conflict = 73,

  #[error("Invalid decryption secret")]
  InvalidEncryptSecret = 74,

  #[error("It appears that the collaboration object's data has not been fully synchronized")]
  CollabDataNotSync = 75,

  #[error("It appears that the workspace data has not been fully synchronized")]
  WorkspaceDataNotSync = 76,

  #[error("Excess storage limited")]
  ExcessStorageLimited = 77,

  #[error("Parse url failed")]
  InvalidURL = 78,

  #[error("Require Email Confirmation, Sign in after email confirmation")]
  AwaitingEmailConfirmation = 79,

  #[error("Text id is empty")]
  TextIdIsEmpty = 80,

  #[error("Record already exists")]
  RecordAlreadyExists = 81,

  #[error("Missing payload")]
  MissingPayload = 82,

  #[error("Permission denied")]
  NotEnoughPermissions = 83,

  #[error("Internal server error")]
  InternalServerError = 84,

  #[error("Not support yet")]
  NotSupportYet = 85,

  #[error("rocksdb corruption")]
  RocksdbCorruption = 86,

  #[error("rocksdb internal error")]
  RocksdbInternal = 87,

  #[error("Local version not support")]
  LocalVersionNotSupport = 88,

  #[error("AppFlowy data folder import error")]
  AppFlowyDataFolderImportError = 89,

  #[error("payload too large")]
  PayloadTooLarge = 90,

  #[error("Workspace limit exceeded")]
  WorkspaceLimitExceeded = 91,

  #[error("Workspace member limit exceeded")]
  WorkspaceMemberLimitExceeded = 92,

  #[error("IndexWriter failed to commit")]
  IndexWriterFailedCommit = 93,

  #[error("Failed to open Index directory")]
  FailedToOpenIndexDir = 94,

  #[error("Failed to parse query")]
  FailedToParseQuery = 95,

  #[error("FolderIndexManager or its dependencies are unavailable")]
  FolderIndexManagerUnavailable = 96,

  #[error("Workspace data not match")]
  WorkspaceDataNotMatch = 97,

  #[error("Local AI error")]
  LocalAIError = 98,

  #[error("Local AI unavailable")]
  LocalAIUnavailable = 99,

  #[error("Storage limit exceeded")]
  FileStorageLimitExceeded = 100,

  #[error("AI Response limit exceeded")]
  AIResponseLimitExceeded = 101,

  #[error("Duplicate record")]
  DuplicateSqliteRecord = 102,

  #[error("Response timeout")]
  ResponseTimeout = 103,

  #[error("Unsupported file format")]
  UnsupportedFileFormat = 104,

  #[error("AppFlowy LAI not ready")]
  AppFlowyLAINotReady = 105,

  #[error("Invalid Request")]
  InvalidRequest = 106,

  #[error("In progress")]
  // when client receives InProgress, it should retry
  InProgress = 107,

  #[error("Upload part size exceeds the limit")]
  SingleUploadLimitExceeded = 108,

  #[error("Group name is empty")]
  GroupNameIsEmpty = 109,

  #[error("Not available for current workspace plan")]
  LimitedByWorkspacePlan = 110,

  #[error("Invalid namespace")]
  InvalidNamespace = 111,

  #[error("Invalid publish name")]
  InvalidPublishName = 112,

  #[error("Custom namespace requires Pro Plan upgrade")]
  CustomNamespaceRequirePlanUpgrade = 113,

  #[error("Requested namespace is not allowed")]
  CustomNamespaceNotAllowed = 114,

  #[error("Requested namespace is already taken")]
  CustomNamespaceAlreadyTaken = 115,

  #[error("Requested namespace is too short")]
  CustomNamespaceTooShort = 116,

  #[error("Requested namespace is too long")]
  CustomNamespaceTooLong = 117,

  #[error("Requested namespace is reserved")]
  CustomNamespaceReserved = 118,

  #[error("Publish name is already used for another published view")]
  PublishNameAlreadyExists = 119,

  #[error("Publish name contains one or more invalid characters")]
  PublishNameInvalidCharacter = 120,

  #[error("Publish name has exceeded the maximum length allowable")]
  PublishNameTooLong = 121,

  #[error("Requested namespace has one or more invalid characters")]
  CustomNamespaceInvalidCharacter = 122,

  #[error("AI Service is unavailable")]
  AIServiceUnavailable = 123,

  #[error("AI Image Response limit exceeded")]
  AIImageResponseLimitExceeded = 124,

  #[error("AI Max Required")]
  AIMaxRequired = 125,

  #[error("View is locked")]
  ViewIsLocked = 126,

  #[error("Request timeout")]
  RequestTimeout = 127,

  #[error("Local AI is not ready")]
  LocalAINotReady = 128,

  #[error("MCP error")]
  MCPError = 129,

  #[error("Local AI disabled")]
  LocalAIDisabled = 130,

  #[error("User not login")]
  UserNotLogin = 131,

  #[error("Reference resource is not available")]
  WeakRefDrop = 132,

  #[error("Local embedding not ready")]
  LocalEmbeddingNotReady = 133,

  #[error("New password is too weak")]
  NewPasswordTooWeak = 134,

  #[error("Invalid new password")]
  InvalidNewPassword = 135,

  #[error("New password is too long")]
  NewPasswordTooLong = 136,

  #[error("New password is too short")]
  NewPasswordTooShort = 137,

  #[error("Guest limit exceeded for free plan")]
  FreePlanGuestLimitExceeded = 138,

  #[error("Guest limit exceeded for paid plan")]
  PaidPlanGuestLimitExceeded = 139,

  #[error("Invalid guest")]
  InvalidGuest = 140,
}

impl ErrorCode {
  pub fn value(&self) -> i32 {
    self.clone() as i32
  }
}
