/***************************************************************************
*
* This file is part of the ManualCamera project.
* Copyright (C) 2015, 2018 Kai Oezer
* https://github.com/robo-fish/ManualCamera
*
* ManualCamera is free software. You can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <https://www.gnu.org/licenses/>.
*
****************************************************************************/
import Photos

class MCPhotoLibrary
{

  static func save(_ image : UIImage)
  {
    var album = _appAlbum()
    if album == nil
    {
      album = _makeAppAlbum()
    }
    if let album_ = album
    {
      do
      {
        try PHPhotoLibrary.shared().performChangesAndWait {
          let assetCreationRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
          if let assetAdditionRequest = PHAssetCollectionChangeRequest(for: album_),
            let asset = assetCreationRequest.placeholderForCreatedAsset
          {
            var assets = [PHObjectPlaceholder]()
            assets.append(asset)
            assetAdditionRequest.addAssets(assets as NSArray)
          }
        }
      }
      catch let err
      {
        print("Error while \(err.localizedDescription)")
      }
    }
  }

  static private func _appAlbum() -> PHAssetCollection?
  {
    var result : PHAssetCollection? = nil
    let albums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
    albums.enumerateObjects({ (album, index, stopPtr) in
      if let title = album.localizedTitle
      {
        if title == "ManualCamera"
        {
          result = album
          stopPtr.pointee = true
        }
      }
    })
    return result
  }

  static private func _makeAppAlbum() -> PHAssetCollection?
  {
    var result : PHAssetCollection? = nil
    var albumPlaceholder : PHObjectPlaceholder?
    do
    {
      try PHPhotoLibrary.shared().performChangesAndWait {
        let creationRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: "ManualCamera")
        albumPlaceholder = creationRequest.placeholderForCreatedAssetCollection;
      }
      if let albumID = albumPlaceholder?.localIdentifier
      {
        try PHPhotoLibrary.shared().performChangesAndWait {
          let albums = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers:[albumID], options:nil)
          albums.enumerateObjects({ (album, index, stopPtr) in
            result = album
            stopPtr.pointee = true
          })
        }
      }
    }
    catch let err
    {
      print("Error while trying to create album for the app. \(err.localizedDescription)")
    }
    return result
  }

#if DEBUG
  static func listPhotos()
  {
    _listAlbums()
    _listSmartAlbums()
    _listMoments()
  }

  // "Albums" are created by the user or by apps.
  static func _listAlbums()
  {
    let options = PHFetchOptions()
    options.includeHiddenAssets = true
    print("Albums")
    let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options)
    collections.enumerateObjects({ (collection, index, stopPtr) in
      print("\t\(collection.localizedTitle ?? "<unknown>")")
      _printAssets(in: collection)
    })
  }

  // Virtual albums, like "Favorites", "Selfies", "Panoramas"
  static func _listSmartAlbums()
  {
    let options = PHFetchOptions()
    options.includeHiddenAssets = true
    print("Smart Albums")
    let result = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: options)
    result.enumerateObjects({ (collection, index, stopPtr) in
      print("\t\(collection.localizedTitle ?? "<unknown>")")
      _printAssets(in: collection)
    })
  }

  // "Moments" are chronologically clustered collections of photos.
  static func _listMoments()
  {
    let options = PHFetchOptions()
    options.includeHiddenAssets = true
    print("Moments")
    let result = PHAssetCollection.fetchMoments(with: options)
    result.enumerateObjects({ (moment, index, stopPtr) in
      print("\t\(moment)")
      _printAssets(in: moment)
    })
  }

  static func _printAssets(in collection : PHAssetCollection)
  {
    let options = PHFetchOptions()
    options.includeHiddenAssets = true
    let assets = PHAsset.fetchAssets(in: collection, options: options)
    assets.enumerateObjects({ (asset, index, stopPtr) in
      print("\t\t\(asset)")
    })
  }
#endif

}

