use flate2::read::ZlibDecoder;
use flowy_error::{FlowyError, FlowyResult};
use image::{DynamicImage, ImageFormat};
use lopdf::Stream;
use std::io::{Cursor, Read};
use std::sync::Arc;
use tracing::{debug, warn};

/// Image format information extracted from PDF stream
#[derive(Debug)]
pub struct ImageInfo {
  pub filter: Option<String>,
  pub color_space: Option<String>,
  #[allow(dead_code)]
  pub bits_per_component: Option<i64>,
  pub width: Option<i64>,
  pub height: Option<i64>,
}

impl ImageInfo {
  /// Extracts image information from a PDF stream
  pub fn from_stream(stream: &Stream) -> Self {
    Self {
      filter: extract_filter(stream),
      color_space: extract_color_space(stream),
      bits_per_component: extract_bits_per_component(stream),
      width: extract_dimension(stream, b"Width"),
      height: extract_dimension(stream, b"Height"),
    }
  }

  /// Checks if the image has valid dimensions
  pub fn has_dimensions(&self) -> bool {
    self.width.is_some() && self.height.is_some()
  }
}

/// Trait for handling different image formats
pub trait ImageFormatHandler {
  /// Returns the name of the format this handler supports
  fn format_name(&self) -> &'static str;

  /// Checks if this handler can process the given image
  fn can_handle(&self, info: &ImageInfo, content: &[u8]) -> bool;

  /// Processes the image and returns JPEG bytes
  fn process(&self, info: &ImageInfo, content: &[u8]) -> FlowyResult<Vec<u8>>;
}

/// Handler for JPEG/DCTDecode format
pub struct JpegHandler;

impl ImageFormatHandler for JpegHandler {
  fn format_name(&self) -> &'static str {
    "JPEG/DCTDecode"
  }

  fn can_handle(&self, info: &ImageInfo, content: &[u8]) -> bool {
    info.filter.as_deref() == Some("DCTDecode") || is_valid_jpeg(content)
  }

  fn process(&self, _info: &ImageInfo, content: &[u8]) -> FlowyResult<Vec<u8>> {
    debug!("Processing JPEG image");

    if !is_valid_jpeg(content) {
      warn!("Image marked as DCTDecode but doesn't have valid JPEG header");
    }

    Ok(content.to_vec())
  }
}

/// Handler for FlateDecode format (compressed images)
pub struct FlateDecodeHandler;

impl ImageFormatHandler for FlateDecodeHandler {
  fn format_name(&self) -> &'static str {
    "FlateDecode"
  }

  fn can_handle(&self, info: &ImageInfo, _content: &[u8]) -> bool {
    info.filter.as_deref() == Some("FlateDecode")
  }

  fn process(&self, info: &ImageInfo, content: &[u8]) -> FlowyResult<Vec<u8>> {
    debug!("Processing FlateDecode image");

    // Decompress the data
    let mut decoder = ZlibDecoder::new(content);
    let mut decompressed = Vec::new();

    decoder.read_to_end(&mut decompressed).map_err(|e| {
      FlowyError::invalid_data()
        .with_context(format!("Failed to decompress FlateDecode image: {}", e))
    })?;

    debug!(
      "Decompressed {} bytes to {} bytes",
      content.len(),
      decompressed.len()
    );

    // Check if it's a PNG
    if is_png(&decompressed) {
      convert_png_to_jpeg(&decompressed)
    } else if info.has_dimensions() {
      // Try to handle as raw bitmap
      convert_raw_bitmap_to_jpeg(info, &decompressed)
    } else {
      Err(
        FlowyError::invalid_data()
          .with_context("Cannot process decompressed data without format information"),
      )
    }
  }
}

/// Handler for raw bitmap images
pub struct RawBitmapHandler;

impl ImageFormatHandler for RawBitmapHandler {
  fn format_name(&self) -> &'static str {
    "Raw Bitmap"
  }

  fn can_handle(&self, info: &ImageInfo, content: &[u8]) -> bool {
    // Handle images with no filter but with dimensions
    info.filter.is_none() && info.has_dimensions() && !is_valid_jpeg(content)
  }

  fn process(&self, info: &ImageInfo, content: &[u8]) -> FlowyResult<Vec<u8>> {
    debug!("Processing raw bitmap image");
    convert_raw_bitmap_to_jpeg(info, content)
  }
}

/// Collection of all available image format handlers
#[derive(Clone)]
pub struct ImageFormatRegistry {
  handlers: Vec<Arc<dyn ImageFormatHandler + Send + Sync>>,
}

impl ImageFormatRegistry {
  /// Creates a new registry with default handlers
  pub fn new() -> Self {
    Self {
      handlers: vec![
        Arc::new(JpegHandler),
        Arc::new(FlateDecodeHandler),
        Arc::new(RawBitmapHandler),
      ],
    }
  }

  /// Processes an image using the appropriate handler
  pub fn process_image(&self, stream: &Stream) -> FlowyResult<Vec<u8>> {
    let info = ImageInfo::from_stream(stream);
    let content = &stream.content;

    // Log image details for debugging
    debug!(
      "Image info - Filter: {:?}, ColorSpace: {:?}, Size: {} bytes, Dimensions: {}x{}",
      info.filter,
      info.color_space,
      content.len(),
      info.width.unwrap_or(0),
      info.height.unwrap_or(0)
    );

    // Find appropriate handler
    for handler in &self.handlers {
      if handler.can_handle(&info, content) {
        debug!("Using {} handler", handler.format_name());
        return handler.process(&info, content);
      }
    }

    Err(FlowyError::invalid_data().with_context(format!(
      "No handler available for image format: {:?}",
      info.filter
    )))
  }
}

impl Default for ImageFormatRegistry {
  fn default() -> Self {
    Self::new()
  }
}

// Helper functions

fn extract_filter(stream: &Stream) -> Option<String> {
  stream
    .dict
    .get(b"Filter")
    .ok()
    .and_then(|f| f.as_name().ok())
    .and_then(|name_bytes| std::str::from_utf8(name_bytes).ok())
    .map(|s| s.to_string())
}

fn extract_color_space(stream: &Stream) -> Option<String> {
  stream
    .dict
    .get(b"ColorSpace")
    .ok()
    .and_then(|cs| cs.as_name().ok())
    .and_then(|name_bytes| std::str::from_utf8(name_bytes).ok())
    .map(|s| s.to_string())
}

fn extract_bits_per_component(stream: &Stream) -> Option<i64> {
  stream
    .dict
    .get(b"BitsPerComponent")
    .ok()
    .and_then(|bpc| bpc.as_i64().ok())
}

fn extract_dimension(stream: &Stream, key: &[u8]) -> Option<i64> {
  stream.dict.get(key).ok().and_then(|v| v.as_i64().ok())
}

fn is_valid_jpeg(bytes: &[u8]) -> bool {
  // JPEG files start with FF D8 FF
  bytes.len() >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF
}

fn is_png(bytes: &[u8]) -> bool {
  // PNG files start with 89 50 4E 47 0D 0A 1A 0A
  bytes.len() >= 8 && bytes[0..8] == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
}

fn convert_png_to_jpeg(png_bytes: &[u8]) -> FlowyResult<Vec<u8>> {
  debug!("Converting PNG to JPEG");

  let img = image::load_from_memory_with_format(png_bytes, ImageFormat::Png).map_err(|e| {
    FlowyError::invalid_data().with_context(format!("Failed to decode PNG image: {}", e))
  })?;

  let mut jpeg_bytes = Vec::new();
  let mut cursor = Cursor::new(&mut jpeg_bytes);

  img.write_to(&mut cursor, ImageFormat::Jpeg).map_err(|e| {
    FlowyError::invalid_data().with_context(format!("Failed to convert PNG to JPEG: {}", e))
  })?;

  debug!(
    "Successfully converted PNG to JPEG ({} bytes)",
    jpeg_bytes.len()
  );
  Ok(jpeg_bytes)
}

fn convert_raw_bitmap_to_jpeg(info: &ImageInfo, bitmap_data: &[u8]) -> FlowyResult<Vec<u8>> {
  let (width, height) = match (info.width, info.height) {
    (Some(w), Some(h)) => (w, h),
    _ => {
      return Err(
        FlowyError::invalid_data().with_context("Missing image dimensions for raw bitmap"),
      );
    },
  };

  // Infer color space if not provided
  let color_space = info
    .color_space
    .as_deref()
    .or_else(|| infer_color_space(bitmap_data.len(), width, height));

  let color_space = color_space.ok_or_else(|| {
    FlowyError::invalid_data().with_context("Cannot determine color space for raw bitmap")
  })?;

  debug!(
    "Converting raw bitmap: {}x{}, color space: {}",
    width, height, color_space
  );

  let dynamic_image = match color_space {
    "DeviceRGB" => create_rgb_image(width as u32, height as u32, bitmap_data)?,
    "DeviceGray" => create_grayscale_image(width as u32, height as u32, bitmap_data)?,
    _ => {
      return Err(
        FlowyError::invalid_data()
          .with_context(format!("Unsupported color space: {}", color_space)),
      );
    },
  };

  // Convert to JPEG
  let mut jpeg_bytes = Vec::new();
  let mut cursor = Cursor::new(&mut jpeg_bytes);

  dynamic_image
    .write_to(&mut cursor, ImageFormat::Jpeg)
    .map_err(|e| {
      FlowyError::invalid_data().with_context(format!("Failed to convert bitmap to JPEG: {}", e))
    })?;

  debug!(
    "Successfully converted bitmap to JPEG ({} bytes)",
    jpeg_bytes.len()
  );
  Ok(jpeg_bytes)
}

fn infer_color_space(data_len: usize, width: i64, height: i64) -> Option<&'static str> {
  let pixel_count = (width * height) as usize;

  match data_len {
    len if len == pixel_count * 3 => {
      debug!("Inferred RGB color space (3 bytes per pixel)");
      Some("DeviceRGB")
    },
    len if len == pixel_count => {
      debug!("Inferred Grayscale color space (1 byte per pixel)");
      Some("DeviceGray")
    },
    len if len == pixel_count * 4 => {
      debug!("Inferred CMYK color space (4 bytes per pixel) - not supported");
      None
    },
    _ => {
      debug!("Could not infer color space from data size");
      None
    },
  }
}

fn create_rgb_image(width: u32, height: u32, data: &[u8]) -> FlowyResult<DynamicImage> {
  let expected_size = (width * height * 3) as usize;
  if data.len() != expected_size {
    return Err(FlowyError::invalid_data().with_context(format!(
      "RGB bitmap size mismatch: expected {}, got {}",
      expected_size,
      data.len()
    )));
  }

  image::RgbImage::from_raw(width, height, data.to_vec())
    .map(DynamicImage::ImageRgb8)
    .ok_or_else(|| {
      FlowyError::invalid_data().with_context("Failed to create RGB image from raw data")
    })
}

fn create_grayscale_image(width: u32, height: u32, data: &[u8]) -> FlowyResult<DynamicImage> {
  let expected_size = (width * height) as usize;
  if data.len() != expected_size {
    return Err(FlowyError::invalid_data().with_context(format!(
      "Grayscale bitmap size mismatch: expected {}, got {}",
      expected_size,
      data.len()
    )));
  }

  image::GrayImage::from_raw(width, height, data.to_vec())
    .map(DynamicImage::ImageLuma8)
    .ok_or_else(|| {
      FlowyError::invalid_data().with_context("Failed to create grayscale image from raw data")
    })
}
