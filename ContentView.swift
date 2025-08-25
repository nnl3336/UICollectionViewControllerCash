//
//  ContentView.swift
//  UICollectionViewControllerCash
//
//  Created by Yuki Sasaki on 2025/08/25.
//

import SwiftUI
import CoreData

import UIKit

import SwiftUI
import PhotosUI

import SwiftUI
import PhotosUI

struct ContentView: View {
    @Environment(\.managedObjectContext) var context
    @State private var selectedPhoto: Photo?
    @State private var pickerItems: [PhotosPickerItem] = []   // 複数選択対応

    var body: some View {
        NavigationView {
            VStack {
                PhotoGridView(selectedPhoto: $selectedPhoto)

                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: 0, // 0 は無制限
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Text("写真を追加")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding()
                .onChange(of: pickerItems) { newItems in
                    loadPhotos(newItems)
                }
            }
            .navigationTitle("Photos")
            .sheet(item: $selectedPhoto) { photo in
                PhotoDetailView(photo: photo)
            }
        }
    }

    func loadPhotos(_ items: [PhotosPickerItem]) {
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                switch result {
                case .success(let data?):
                    DispatchQueue.main.async {
                        let newPhoto = Photo(context: context)
                        newPhoto.creationDate = Date()
                        newPhoto.imageData = data
                        do {
                            try context.save()
                        } catch {
                            print("保存失敗: \(error)")
                        }
                    }
                case .success(nil):
                    print("データなし")
                case .failure(let error):
                    print("読み込み失敗: \(error)")
                }
            }
        }
        pickerItems = [] // 選択リセット
    }
}

struct PhotoGridView: UIViewControllerRepresentable {
    @Environment(\.managedObjectContext) private var context
    @Binding var selectedPhoto: Photo?

    func makeUIViewController(context: Context) -> PhotoCollectionViewController {
        let vc = PhotoCollectionViewController(context: self.context)
        vc.onSelectPhoto = { photo in
            DispatchQueue.main.async { self.selectedPhoto = photo }
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: PhotoCollectionViewController, context: Context) {}
}


class PhotoCollectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    var collectionView: UICollectionView!
    var frc: NSFetchedResultsController<Photo>!
    var onSelectPhoto: ((Photo) -> Void)?
    
    init(context: NSManagedObjectContext) {
        super.init(nibName: nil, bundle: nil)
        setupFRC(context: context)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupFRC(context: NSManagedObjectContext) {
        let request: NSFetchRequest<Photo> = Photo.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Photo.creationDate, ascending: true)]
        request.fetchBatchSize = 50

        frc = NSFetchedResultsController(fetchRequest: request,
                                         managedObjectContext: context,
                                         sectionNameKeyPath: nil,
                                         cacheName: nil)
        frc.delegate = self

        try? frc.performFetch()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 100, height: 100)
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "Cell")
        view.addSubview(collectionView)
    }

    // UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        frc.fetchedObjects?.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! PhotoCell
        if let photo = frc.fetchedObjects?[indexPath.item], let data = photo.imageData {
            cell.imageView.image = UIImage(data: data)
        } else {
            cell.imageView.image = UIImage(systemName: "photo")
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let photo = frc.fetchedObjects?[indexPath.item] {
            onSelectPhoto?(photo)
        }
    }
}

extension PhotoCollectionViewController: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        collectionView.reloadData()
    }
}

//

struct PhotoDetailView: View {
    let photo: Photo
    
    var body: some View {
        VStack {
            if let data = photo.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
            }
        }
        .padding()
    }
}

class PhotoCell: UICollectionViewCell {
    let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.frame = contentView.bounds
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
